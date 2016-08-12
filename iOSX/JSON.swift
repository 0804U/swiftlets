//
//  NSURLSession+JSON.swift
//  swiftlets
//
//  Created by Frank Vernon on 6/22/16.
//  Copyright © 2016 Frank Vernon. All rights reserved.
//
// Based, in large part, upon: https://github.com/dankogai/swift-json
// Copyright (c) 2014 Dan Kogai

import Foundation

/**
 Protocol one can adopt to convert to and from JSON primative types: Number, String, NULL, Array, Dictionary
 
 ```
 extension NSDate: JSONTransformable {
    func toJSONType() -> AnyObject {
        return NSDateFormatter.ISO8601FormatterCached(.microseconds).stringFromDate(self)
    }
 
    public static func fromJSONType(json:AnyObject) -> AnyObject? {
        guard let jsonString:String = json as? String else {
            return nil
        }

        return NSDateFormatter.ISO8601FormatterCached(.microseconds).dateFromString(jsonString)
    }
 }

 ```
 */
public protocol JSONTransformable {
    func toJSONType() -> AnyObject
    static func fromJSONType(json:AnyObject) -> AnyObject?
}

/**
 Representation of a JSON element which may have a nil (NULL) value. Nil values
 will be substitued with NSNull() objects automatically when added to a JSON object.
 
 This is useful primarily for creating JSON objects where the value may be nil. 
*/
public typealias JSONElement = [String:AnyObject?]

/// init
public class JSON {
    private var value:AnyObject

    func transform<T:JSONTransformable>() -> T? {
        return T.fromJSONType(value) as? T
    }

    /// unwraps the JSON object
    public class func unwrap(obj:AnyObject?) -> AnyObject {
        switch obj {
        case let json as JSON:
            return json.value ?? NSNull()
            
        case let array as NSArray:
            var result = [AnyObject]()
            for element in array {
                result.append(unwrap(element))
            }
            return result
            
        case let dictionary as NSDictionary:
            var result = [String:AnyObject]()
            for (key, value) in dictionary {
                if let k = key as? String {
                    result[k] = unwrap(value)
                }
            }
            return result

        case let transform as JSONTransformable:
            return transform.toJSONType()

        default:
            return obj ?? NSNull()
        }
    }
    
    public class func unwrap(element:JSONElement) -> AnyObject {
        var result = [String:AnyObject]()
        for (key, value) in element {
            result[key] = unwrap(value)
        }
        return result
    }
    
    public init(_ object:AnyObject?) {
        self.value = JSON.unwrap(object)
    }
    
    public init(_ element:JSONElement) {
        self.value = JSON.unwrap(element)
    }
    
    public init(_ json:JSON) {
        self.value = json.value
    }
}

/// class properties
extension JSON {
    public typealias NSNull = Foundation.NSNull
    public typealias NSError = Foundation.NSError
    public class var null:NSNull {
        return NSNull()
    }
    
    /// constructs JSON object from data
    public convenience init(data:NSData) {
        var err:NSError?
        var obj:AnyObject?
        do {
            obj = try NSJSONSerialization.JSONObjectWithData(data, options:[])
        } catch let error as NSError {
            err = error
            obj = nil
        }
        self.init(err != nil ? err! : obj!)
    }
    
    /// constructs JSON object from string
    public convenience init(string:String) {
        self.init(data: string.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
    
    /// parses string to the JSON object
    /// same as JSON(string:String)
    public class func parse(string:String)->JSON {
        return JSON(string:string)
    }
    
    /// constructs JSON object from the content of NSURL
    public convenience init(nsurl:NSURL) {
        var enc:NSStringEncoding = NSUTF8StringEncoding
        do {
            let str = try NSString(contentsOfURL:nsurl, usedEncoding:&enc)
            self.init(string:str as String)
        } catch let err as NSError {
            self.init(err)
        }
    }
    
    /// fetch the JSON string from NSURL and parse it
    /// same as JSON(nsurl:NSURL)
    public class func fromNSURL(nsurl:NSURL) -> JSON {
        return JSON(nsurl:nsurl)
    }
    
    public func toData() -> NSData? {
        return toString(false).dataUsingEncoding(NSUTF8StringEncoding)
    }

    /// constructs JSON object from the content of URL
    public convenience init(url:String) {
        if let nsurl = NSURL(string:url) as NSURL? {
            self.init(nsurl:nsurl)
        } else {
            self.init(NSError(
                domain:"JSONErrorDomain",
                code:400,
                userInfo:[NSLocalizedDescriptionKey: "malformed URL"]
                )
            )
        }
    }
    
    /// fetch the JSON string from URL in the string
    public class func fromURL(url:String) -> JSON {
        return JSON(url:url)
    }
    
    /// does what JSON.stringify in ES5 does.
    /// when the 2nd argument is set to true it pretty prints
    public class func stringify(obj:AnyObject, prettyPrint:Bool=false) -> String! {
        if !NSJSONSerialization.isValidJSONObject(obj) {
            let error = JSON(NSError(
                domain:"JSONErrorDomain",
                code:422,
                userInfo:[NSLocalizedDescriptionKey: "not an JSON object"]
                ))
            return JSON(error).toString(prettyPrint)
        }
        return JSON(obj).toString(prettyPrint)
    }
}

/// instance properties
extension JSON {
    /// access the element like array
    public subscript(index:Int) -> JSON {
        get {
        switch value {
        case _ as NSError:
            return self
        case let array as NSArray:
            if 0 <= index && index < array.count {
                return JSON(array[index])
            }
            return JSON(NSError(
                domain:"JSONErrorDomain", code:404, userInfo:[
                    NSLocalizedDescriptionKey:
                        "[\(index)] is out of range"
                ]))
        default:
            return JSON(NSError(
                domain:"JSONErrorDomain", code:500, userInfo:[
                    NSLocalizedDescriptionKey: "not an array"
                ]))
        }
        }

        set (newValue) {
            updateValue(newValue, atIndex: index)
        }
    }

    /// access the element like dictionary
    public subscript(key:String)->JSON {
        get {
            switch value {
            case _ as NSError:
                return self
            case let dictionary as NSDictionary:
                if let val:AnyObject = dictionary[key] { return JSON(val) }
                return JSON(NSError(
                    domain:"JSONErrorDomain", code:404, userInfo:[
                        NSLocalizedDescriptionKey:
                            "[\"\(key)\"] not found"
                    ]))
            default:
                return JSON(NSError(
                    domain:"JSONErrorDomain", code:500, userInfo:[
                        NSLocalizedDescriptionKey: "not an object"
                    ]))
            }
        }

        set (newValue) {
            updateValue(newValue, forKey: key)
        }
    }

    public func removeValue(forKey key:String) {
        switch value {
        case var valueDictionary as Dictionary<String, AnyObject>:
            valueDictionary.removeValueForKey(key)
            value = valueDictionary
        default:
            break
        }
    }

    public func removeValue(atIndex index:Int) {
        switch value {
        case var valueArray as Array<AnyObject>:
            valueArray.removeAtIndex(index)
            value = valueArray
        default:
            break
        }
    }

    public func updateValue(newValue:AnyObject?, forKey key:String) {
        let json:JSON = JSON(newValue)
        switch value {
        case var valueDictionary as Dictionary<String, AnyObject>:
            valueDictionary[key] = json.value
            value = valueDictionary
        default:
            break
        }
    }

    public func updateValue(newValue:AnyObject?, atIndex index:Int) {
        let json:JSON = JSON(newValue)
        switch value {
        case var valueArray as Array<AnyObject>:
            valueArray[index] = json.value
            value = valueArray
        default:
            break
        }
    }

    /// access json data object
    public var data:AnyObject? {
        return self.isError ? nil : self.value
    }
    
    /// Gives the type name as string.
    /// e.g.  if it returns "Double"
    ///       .asDouble returns Double
    public var type:String {
        switch value {
        case is NSError:        return "NSError"
        case is NSNull:         return "NSNull"
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":              return "Bool"
            case "q", "l", "i", "s":    return "Int"
            case "Q", "L", "I", "S":    return "UInt"
            default:                    return "Double"
            }
        case is NSString:               return "String"
        case is NSArray:                return "Array"
        case is NSDictionary:           return "Dictionary"
        default:                        return "NSError"
        }
    }
    
    /// check if self is NSError
    public var isError:      Bool { return value is NSError }
    /// check if self is NSNull
    public var isNull:       Bool { return value is NSNull }
    /// check if self is Bool
    public var isBool:       Bool { return type == "Bool" }
    /// check if self is Int
    public var isInt:        Bool { return type == "Int" }
    /// check if self is UInt
    public var isUInt:       Bool { return type == "UInt" }
    /// check if self is Double
    public var isDouble:     Bool { return type == "Double" }
    /// check if self is any type of number
    public var isNumber:     Bool {
        if let o = value as? NSNumber {
            let t = String.fromCString(o.objCType)!
            return  t != "c" && t != "C"
        }
        return false
    }
    
    /// check if self is String
    public var isString:     Bool { return value is NSString }
    /// check if self is Array
    public var isArray:      Bool { return value is NSArray }
    /// check if self is Dictionary
    public var isDictionary: Bool { return value is NSDictionary }
    /// check if self is a valid leaf node.
    public var isLeaf:       Bool {
        return !(isArray || isDictionary || isError)
    }
    
    /// gives NSError if it holds the error. nil otherwise
    public var asError:NSError? {
        return value as? NSError
    }
    
    /// gives NSNull if self holds it. nil otherwise
    public var asNull:NSNull? {
        return value is NSNull ? JSON.null : nil
    }
    
    /// gives Bool if self holds it. nil otherwise
    public var asBool:Bool? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":  return Bool(o.boolValue)
            default:
                return nil
            }
        default: return nil
        }
    }
    
    /// gives Int if self holds it. nil otherwise
    public var asInt:Int? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return Int(o.longLongValue)
            }
        default: return nil
        }
    }

    /// gives UInt if self holds it. nil otherwise
    public var asUInt:UInt? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return UInt(o.unsignedLongValue)
            }
        default: return nil
        }
    }

    /// gives Int32 if self holds it. nil otherwise
    public var asInt32:Int32? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return Int32(o.longLongValue)
            }
        default: return nil
        }
    }
    
    /// gives Int64 if self holds it. nil otherwise
    public var asInt64:Int64? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return Int64(o.longLongValue)
            }
        default: return nil
        }
    }

    /// gives Int32 if self holds it. nil otherwise
    public var asUInt32:UInt32? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return UInt32(o.unsignedLongLongValue)
            }
        default: return nil
        }
    }

    /// gives Int64 if self holds it. nil otherwise
    public var asUInt64:UInt64? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return UInt64(o.unsignedLongLongValue)
            }
        default: return nil
        }
    }

    /// gives Float if self holds it. nil otherwise
    public var asFloat:Float? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return Float(o.floatValue)
            }
        default: return nil
        }
    }
    
    /// gives Double if self holds it. nil otherwise
    public var asDouble:Double? {
        switch value {
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return nil
            default:
                return Double(o.doubleValue)
            }
        default: return nil
        }
    }
    
    // an alias to asDouble
    public var asNumber:Double? { return asDouble }
    /// gives String if self holds it. nil otherwise
    public var asString:String? {
        switch value {
        case let o as NSString:
            return o as String
        default: return nil
        }
    }
    
    /// if self holds NSArray, gives a [JSON]
    /// with elements therein. nil otherwise
    public var asArray:[JSON]? {
        switch value {
        case let o as NSArray:
            var result = [JSON]()
            for v:AnyObject in o { result.append(JSON(v)) }
            return result
        default:
            return nil
        }
    }
    
    /// if self holds NSDictionary, gives a [String:JSON]
    /// with elements therein. nil otherwise
    public var asDictionary:[String:JSON]? {
        switch value {
        case let o as NSDictionary:
            var result = [String:JSON]()
            for (ko, v): (AnyObject, AnyObject) in o {
                if let k = ko as? String {
                    result[k] = JSON(v)
                }
            }
            return result
        default: return nil
        }
    }

    /// if self holds NSDictionary, gives a JSONElement
    /// with elements therein. nil otherwise
    public var asElement:JSONElement? {
        switch value {
        case let o as NSDictionary:
            var result = JSONElement()
            for (ko, v): (AnyObject, AnyObject) in o {
                if let k = ko as? String {
                    result[k] = v
                }
            }
            return result
        default: return nil
        }
    }

    /// Yields date from string
    public var asDate:NSDate? {
        if let dateString = value as? String {
            return NSDateFormatter.tryParseISO8601LikeDateString(dateString)
        }
        return nil
    }

    func asTransformable<T:JSONTransformable>() -> T? {
        return T.fromJSONType(value) as? T
    }

    /// gives the number of elements if an array or a dictionary.
    /// you can use this to check if you can iterate.
    public var count:Int {
        switch value {
        case let o as NSArray:      return o.count
        case let o as NSDictionary: return o.count
        default: return 0
        }
    }
    
    public var length:Int { return self.count }
    // gives all values content in JSON object.
    public var allValues:JSON{
        if(self.value.allValues == nil) {
            return JSON([])
        }
        return JSON(self.value.allValues)
    }
    
    // gives all keys content in JSON object.
    public var allKeys:JSON{
        if(self.value.allKeys == nil) {
            return JSON([])
        }
        return JSON(self.value.allKeys)
    }
}

extension JSON : SequenceType {
    public func generate()->AnyGenerator<(AnyObject,JSON)> {
        switch value {
        case let o as NSArray:
            var i = -1
            return AnyGenerator {
                i += 1
                if i == o.count { return nil }
                return (i, JSON(o[i]))
            }
        case let o as NSDictionary:
            var ks = Array(o.allKeys.reverse())
            return AnyGenerator {
                if ks.isEmpty { return nil }
                if let k = ks.removeLast() as? String {
                    return (k, JSON(o.valueForKey(k)!))
                } else {
                    return nil
                }
            }
        default:
            return AnyGenerator{ nil }
        }
    }
    
    public func mutableCopyOfTheObject() -> AnyObject {
        return value.mutableCopy()
    }
}

extension JSON : CustomStringConvertible {
    /// stringifies self.
    /// if pretty:true it pretty prints
    public func toString(pretty:Bool=false)->String {
        switch value {
        case is NSError: return "\(value)"
        case is NSNull: return "null"
        case let o as NSNumber:
            switch String.fromCString(o.objCType)! {
            case "c", "C":
                return o.boolValue.description
            case "q", "l", "i", "s":
                return o.longLongValue.description
            case "Q", "L", "I", "S":
                return o.unsignedLongLongValue.description
            default:
                switch o.doubleValue {
                case 0.0/0.0:   return "0.0/0.0"    // NaN
                case -1.0/0.0:  return "-1.0/0.0"   // -infinity
                case +1.0/0.0:  return "+1.0/0.0"   //  infinity
                default:
                    return o.doubleValue.description
                }
            }
        case let o as NSString:
            return o.debugDescription
        default:
            let opts = pretty ? NSJSONWritingOptions.PrettyPrinted : NSJSONWritingOptions()
            if let data = (try? NSJSONSerialization.dataWithJSONObject(value, options:opts)) as NSData? {
                if let result = NSString(data:data, encoding:NSUTF8StringEncoding) as? String {
                    return result
                }
            }
            return ""
        }
    }
    
    public var description:String {
        return toString(true)
    }

    public var debugDescription:String {
        return toString(true)
    }
}

extension JSON : Equatable {}
public func ==(lhs:JSON, rhs:JSON)->Bool {
    if lhs.isError || rhs.isError {
        return false
    }
    else if lhs.isLeaf {
        if lhs.isNull   { return lhs.asNull   == rhs.asNull }
        if lhs.isBool   { return lhs.asBool   == rhs.asBool }
        if lhs.isNumber { return lhs.asNumber == rhs.asNumber }
        if lhs.isString { return lhs.asString == rhs.asString }
    }
    else if lhs.isArray {
        for i in 0..<lhs.count {
            if lhs[i] != rhs[i] { return false }
        }
        return true
    }
    else if lhs.isDictionary {
        for (k, v) in lhs.asDictionary! {
            if v != rhs[k] { return false }
        }
        return true
    }
    fatalError("JSON == JSON failed!")
}

//MARK: - NSURLSession JSON Extensions

private let kHTTPPostMethod:String = "POST"
private let kHTTPGetMethod:String = "GET"
private let kHTTPAcceptHeader:String = "Accept"
private let kHTTPContentTypeHeader:String = "Content-Type"
private let kHTTPContentTypeJSON:String = "application/json"
private let kHTTPContentTypeFormURLEncoded:String = "application/x-www-form-urlencoded"

public typealias HTTPJSONSuccessClosure = (NSHTTPURLResponse, JSON) -> Void
public typealias HTTPJSONFailureClosure = (NSHTTPURLResponse?, NSError?) -> Void

public extension NSURLSession {

    //MARK: - Get

    /**
     Perform GET request and expect JSON result in response.

     - note: It is guaranteed that exactly one of the success or failure closures will be invoked after this method is called regardless of whether a valid NSURLSessionDataTask is returned.

     - parameters:
         - url: The url of the request
         - success: A closure to be called on success. The NSURLResponse and a JSON object will be included.
         - failure: A closure to be called on failure. The NSURLResponse and an error may be included.
     - returns: NSURLSessionDataTask already resumed
     */

    func httpGet(url:NSURL, success:HTTPJSONSuccessClosure, failure:HTTPJSONFailureClosure) -> NSURLSessionDataTask?
    {
        return httpDataTask(url,
                            method: kHTTPGetMethod,
                            contentType: nil,
                            body: nil,
                            success: success,
                            failure: failure);
    }

    //MARK: - POST

    /**
     Perform POST request and expect JSON result in response.

     - note: It is guaranteed that exactly one of the success or failure closures will be invoked after this method is called regardless of whether a valid NSURLSessionDataTask is returned.

     - parameters:
         - url: The url of the request
         - success: A closure to be called on success. The NSURLResponse and a JSON object will be included.
         - failure: A closure to be called on failure. The NSURLResponse and an error may be included.
     - returns: NSURLSessionDataTask already resumed
     */

    func httpPost(url:NSURL, success:HTTPJSONSuccessClosure, failure:HTTPJSONFailureClosure) -> NSURLSessionDataTask?
    {
        return httpDataTask(url,
                            method: kHTTPPostMethod,
                            contentType: kHTTPContentTypeJSON,
                            body: nil,
                            success: success,
                            failure: failure);
    }

    /**
     Perform POST request with a JSON payload in the body and expect JSON result in response.

     - note: It is guaranteed that exactly one of the success or failure closures will be invoked after this method is called regardless of whether a valid NSURLSessionDataTask is returned.

     - parameters:
         - url: The url of the request
         - bodyJSON: An optional JSON object to included as the body of the post
         - success: A closure to be called on success. The NSURLResponse and a JSON object will be included.
         - failure: A closure to be called on failure. The NSURLResponse and an error may be included.
     - returns: NSURLSessionDataTask already resumed
     */

    func httpPost(url:NSURL, bodyJSON:JSON, success:HTTPJSONSuccessClosure, failure:HTTPJSONFailureClosure) -> NSURLSessionDataTask?
    {
        let data:NSData? = bodyJSON.toData()

        return httpDataTask(url,
                            method: kHTTPPostMethod,
                            contentType: kHTTPContentTypeJSON,
                            body: data,
                            success: success,
                            failure: failure);
    }

    /**
     Perform POST request with a URL parameter payload in the body and expect JSON result in response.

     - note: It is guaranteed that exactly one of the success or failure closures will be invoked after this method is called regardless of whether a valid NSURLSessionDataTask is returned.

     - parameters:
         - url: The url of the request
         - bodyParameters: An optional array of NSURLQueryItem to be escaped and included in the body of the post
         - success: A closure to be called on success. The NSURLResponse and a JSON object will be included.
         - failure: A closure to be called on failure. The NSURLResponse and an error may be included.
     - returns: NSURLSessionDataTask already resumed
     */

    func httpPost(url:NSURL, bodyParameters:[NSURLQueryItem], success:HTTPJSONSuccessClosure, failure:HTTPJSONFailureClosure) -> NSURLSessionDataTask?
    {
        var body:String = ""
        for queryItem:NSURLQueryItem in bodyParameters {
            guard let escapedItem = queryItem.urlEscapedItem() else {
                continue
            }
            
            if !body.isEmpty {
                body = body + "&" + escapedItem
            } else {
                body = escapedItem
            }
        }
        let data:NSData? = body.dataUsingEncoding(NSUTF8StringEncoding)

        return httpDataTask(url,
                            method: kHTTPPostMethod,
                            contentType: kHTTPContentTypeFormURLEncoded,
                            body: data,
                            success: success,
                            failure: failure);
    }

    //MARK: - Utility

    ///Utilty method to create an automatically resumed data task given the input configuration.
    /// The body of the result is assumed to be JSON and is parsed and returned as such.
    private func httpDataTask(url:NSURL,
                              method:String,
                              contentType:String?,
                              body:NSData?,
                              success:HTTPJSONSuccessClosure,
                              failure:HTTPJSONFailureClosure) -> NSURLSessionDataTask?
    {
        func dataTaskSuccessHandler(request:NSURLRequest?, data:NSData?, response:NSHTTPURLResponse, error:NSError?) {
            #if DUMP_NETWORK_RESULTS
                printResult(request, data: data, response: response, error: error)
            #endif

            gcd.main().async {
                success(response, JSON(data: data ?? NSData()))
            }
        }

        func dataTaskFailureHandler(request:NSURLRequest?, data:NSData?, response:NSHTTPURLResponse?, error:NSError?) {
            #if DUMP_NETWORK_RESULTS || DEBUG
                printResult(request, data: data, response: response, error: error)
            #endif

            gcd.main().async {
                if let data = data where error == nil {
                    failure(response, NSError(domain: #function, code: 0, userInfo: ["data":data]))
                } else {
                    failure(response, error)
                }
            }
        }

        //ensure request is valid
        guard let request:NSMutableURLRequest = NSMutableURLRequest(URL: url) else {
            dataTaskFailureHandler(nil, data: nil, response: nil, error: NSError(domain: "NSURLSession.httpPost.badRequest", code: 0, userInfo: nil))
            return nil
        }

        //configure content-type
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: kHTTPContentTypeHeader)
        }

        //configure request to expect JSON result
        request.setValue(kHTTPContentTypeJSON, forHTTPHeaderField: kHTTPAcceptHeader)

        //configure method
        request.HTTPMethod = method

        //add body, if appropriate
        if let body = body {
            request.HTTPBody = body
        }

        //create data task
        let dataTask = dataTaskWithRequest(request) { (data, response, error) in
            if let httpResponse:NSHTTPURLResponse = response as? NSHTTPURLResponse {
                if httpResponse.isSuccess() {
                    dataTaskSuccessHandler(request, data: data, response:httpResponse, error: error)
                } else {
                    dataTaskFailureHandler(request, data: data, response:httpResponse, error: error)
                }
            } else {
                dataTaskFailureHandler(request, data: data, response:nil, error: error)
            }
        }

        //resume task
        dataTask.resume();

        return dataTask
    }

    ///Utility method to print response and error objects for debugging purposes
    private func printResult(request:NSURLRequest?, data:NSData?, response:NSHTTPURLResponse?, error:NSError?) {
        var result:String = "httpDataTask result >>>>>>>>>>\n\n"

        if let request = request {
            result += String("request: \(request)\n\n")
        }

        if let data = data {
            result += String("data: \(String(data:data, encoding:NSUTF8StringEncoding))\n\n")
        }

        if let response = response {
            result += String("response: \(response)\n\n")
        }

        if let error = error {
            result += String("error: \(error.localizedDescription)\n\n")
        }

        result += "<<<<<<<<<"

        print(result)
    }
}