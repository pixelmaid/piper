//
//  Drawing.swift
//  PaletteKnife
//
//  Created by JENNIFER MARY JACOBS on 6/24/16.
//  Copyright © 2016 pixelmaid. All rights reserved.
//

import Foundation

//Drawing
//stores geometry

class Drawing: TimeSeries, WebTransmitter, Hashable{
   var id = NSUUID().UUIDString;
    var currentStroke:Stroke?;
    var geometry = [Geometry]();
    var transmitEvent = Event<(String)>()

       var geometryModified = Event<(Geometry,String,String)>()
    
    //MARK: - Hashable
    var hashValue : Int {
        get {
            return "\(self.id)".hashValue
        }
    }
    
    override init(){
        super.init()
        self.name = "drawing"

    }
    func newStroke(){
        self.currentStroke = Stroke();
        self.geometry.append(self.currentStroke!)
        var data = "\"drawing_id\":\""+self.id+"\","
        data += "\"stroke_id\":\""+self.currentStroke!.id+"\","
        data += "\"time\":\""+String(self.getTimeElapsed())+"\","

        data += "\"type\":\"new_stroke\""
        self.transmitEvent.raise((data))
    }
    
    func addSegmentToStroke(point:PointEmitter, weight:Float){
        if(self.currentStroke == nil){
            print("tried to add segment to stroke, but no stroke exists")
           return
        }
        
        var seg = self.currentStroke!.addSegment(point)
        seg.diameter = weight;
        var data = "\"drawing_id\":\""+self.id+"\","
        data += "\"stroke_id\":\""+self.currentStroke!.id+"\","
        data += "\"type\":\"stroke_data\","
        data += "\"strokeData\":{"
        data += "\"segments\":"+seg.toJSON()+",";
        data += "\"lengths\":{\"length\":"+String(currentStroke!.getLength())+",\"time\":"
        data += String(self .getTimeElapsed())
        data += "}}"
        self.transmitEvent.raise((data))
        self.geometryModified.raise((seg,"SEGMENT","DRAW"))
    }
    
}


// MARK: Equatable
func ==(lhs:Drawing, rhs:Drawing) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}

  
