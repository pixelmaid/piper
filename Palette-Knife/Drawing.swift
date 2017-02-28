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
    var stroke_counter = Int(0);
    var id = NSUUID().UUIDString;
    var activeStrokes = [String:[Stroke]]();
    var allStrokes = [String:[Stroke]]();
    var bakeQueue = [String:[Stroke]]();
    var toSendBake = [Stroke]();
    var bakedStrokes = [Stroke]();
    var drawnStrokes  = [String:[Stroke]]();
    var selectedStrokes = [Stroke]();
    // var geometry = [Geometry]();
    var transmitEvent = Event<(String)>()
    var initEvent = Event<(WebTransmitter,String)>()
    
    let gCodeGenerator = GCodeGenerator();
    let svgGenerator = SVGGenerator();
    
    var geometryModified = Event<(Any,String,String)>()
    
    override init(){
        super.init();
        gCodeGenerator.startDrawing();
        self.name = "drawing"
    }
    
    //TODO: fix getGcode function
    func getGcode()->String{
        /* var source = gCodeGenerator.source;
         for list in self.allStrokes{
         
         for i in 0..<list.1.count{
         source+=list.1[i].gCodeGenerator.source;
         source+=gCodeGenerator.endSegment(list.1[i].segments[list.1[i].segments.count-1]);
         }
         }
         source += gCodeGenerator.end();(
         return source*/
        return ""
    }
    
    func getSVG()->String{
        var orderedStrokes = [Stroke]()
        for list in self.allStrokes{
            for i in 0..<list.1.count{
                orderedStrokes.append(list.1[i])
            }
        }
        return svgGenerator.generate(orderedStrokes)
        
    }
    
    func hitTest(point:Point,threshold:Float)->Stroke?{
        for list in allStrokes {
            for stroke in list.1{
                let seg = stroke.hitTest(point,threshold:threshold);
                if(seg != nil){
                    return stroke;
                }
            }
        }
        return nil
    }
    
    //MARK: - Hashable
    var hashValue : Int {
        get {
            return "\(self.id)".hashValue
        }
    }
    
    func retireCurrentStrokes(parentID:String){
        if (self.activeStrokes[parentID] != nil){
            self.activeStrokes[parentID]!.removeAll();
        }
    }
    
    
    
    
    func newStroke(parentID:String)->Stroke{
        let stroke = Stroke(parentID:parentID);
        stroke.name = "stroke "+String(stroke_counter);
        stroke_counter+=1;
        stroke.parentID = parentID;
        if (self.activeStrokes[parentID] == nil){
            self.activeStrokes[parentID] = [Stroke]()
        }
        self.activeStrokes[parentID]!.append(stroke);
        
        if (self.allStrokes[parentID] == nil){
            self.allStrokes[parentID] = [Stroke]()
            
        }
        if (self.bakeQueue[parentID] == nil){
            self.bakeQueue[parentID] = [Stroke]()
            
        }
        
        
        self.allStrokes[parentID]!.append(stroke);
        self.bakeQueue[parentID]!.append(stroke)
        //self.geometry.append(self.currentStroke!)
        var data = "\"drawing_id\":\""+self.id+"\","
        data += "\"stroke_id\":\""+stroke.id+"\","
        data += "\"time\":\""+String(self.getTimeElapsed())+"\","
        
        data += "\"type\":\"new_stroke\""
        //self.transmitEvent.raise((data))
        
        //TODO: START HERE TOMORROW- don't know position of new stroke here, need to adjust gcode generator to match
        self.geometryModified.raise((stroke,"NEW_STROKE","NEW_STROKE"))
        
        return stroke;
    }
    
    func addSegmentToStroke(parentID:String, point:Point, weight:Float, color:Color){
        if (self.activeStrokes[parentID] == nil){
            return
        }
        for i in 0..<self.activeStrokes[parentID]!.count{
            let currentStroke = self.activeStrokes[parentID]![i]
            var seg = currentStroke.addSegment(point,d:weight)
            if(seg != nil){
                seg!.color = color;
                var data = "\"drawing_id\":\""+self.id+"\","
                data += "\"stroke_id\":\""+currentStroke.id+"\","
                data += "\"type\":\"stroke_data\","
                data += "\"strokeData\":{"
                data += "\"segments\":"+seg!.toJSON()+",";
                data += "\"lengths\":{\"length\":"+String(currentStroke.getLength())+",\"time\":"
                data += String(self .getTimeElapsed())
                data += "}}"
                //self.transmitEvent.raise((data))
                self.geometryModified.raise((seg!,"SEGMENT","DRAW"))
            }
        }
    }
    
    
    func getAllStrokes()->[Stroke]{
        if(ToolManager.bakeMode == "ASAP"){
            return toSendBake+bakedStrokes;
        }
        else{
            var strokes = [Stroke]();
            for (_,s) in self.allStrokes{
                strokes = strokes+s;
            }
            return strokes
        }
    }
    
    func deselectAllStrokes(){
        
        for s in self.selectedStrokes{
            s.selected=false;
        }
        self.selectedStrokes.removeAll();
        
    }
    
    func selectStroke(stroke:Stroke){
        self.selectedStrokes.append(stroke);
        stroke.selected = true;
    }
    
    func deselectStroke(stroke:Stroke){
        for i in 0..<self.selectedStrokes.count{
            if stroke.id == self.selectedStrokes[i].id{
                self.selectedStrokes.removeAtIndex(i)
                break;
                
            }
        }
    }
    
    func bake(parentID:String){
        var source_string = "[";
        if(bakeQueue[parentID] != nil){
            var bq = bakeQueue[parentID]!
            for i in 0..<bq.count{
                self.toSendBake.append(bq[i]);
            }
            bakeQueue[parentID]?.removeAll();
            
            
            if(GCodeGenerator.fabricatorStatus.get(nil) == 0){
                self.bakeNext();
            }
        }
    }
    
    func bakeSelected(){
        let data = self.generateBakeData(self.selectedStrokes);
        self.deselectAllStrokes();
        for i in 0..<data.count{
        self.transmitEvent.raise((data[i]));
        }
        print("source",data);
    }
    
    func bakeNext()->String?{
        if(toSendBake.count>0){
            let strokes = [toSendBake.removeFirst()];
            let data = self.generateBakeData(strokes);
            self.transmitEvent.raise((data[0]));
            print("source",data);
            return id;
        }
        return nil;
        
    }
    
    func generateBakeData(strokes:[Stroke])->[String]{
       
        var data_collection = [String]();
        for i in 0..<strokes.count{
             var source_string = "[";
            let stroke = strokes[i];
            stroke.baked = true;
            var source = stroke.gCodeGenerator.source;
            let id = stroke.id;
            var segments = stroke.segments;
            print("segments=\(segments)");
            let _x = Numerical.map(segments[0].point.x.get(nil), istart:GCodeGenerator.pX, istop: 0, ostart: GCodeGenerator.inX, ostop: 0)
            
            let _y = Numerical.map(segments[0].point.y.get(nil), istart:0, istop:GCodeGenerator.pY, ostart:  GCodeGenerator.inY, ostop: 0 )
            
            source_string += "\""+stroke.gCodeGenerator.jog3(_x,y:_y,z: GCodeGenerator.retractHeight)+"\"";
            for j in 0..<source.count{
                
                source_string += ",\""+source[j]+"\""
            }
            
            source_string+=",\""+gCodeGenerator.endSegment(segments[segments.count-1])+"\"]"
            bakedStrokes.append(stroke);
            var data = "\"drawing_id\":\""+self.id+"\","
            data += "\"type\":\"gcode\","
            data += "\"data\":"+source_string
            print("data \(data)");
            
            data_collection.append(data);
        }
        return data_collection;
    }
    
    func moveStrokeDown(strokeId:String){
        for i in 0..<toSendBake.count{
            if(toSendBake[i].id == strokeId){
                let stroke = toSendBake.removeAtIndex(i);
                toSendBake.insert(stroke, atIndex: i+1);
                break;
                
            }
        }
    }
    
    func moveStrokeUp(strokeId:String){
        for i in 0..<toSendBake.count{
            if(toSendBake[i].id == strokeId){
                let stroke = toSendBake.removeAtIndex(i);
                toSendBake.insert(stroke, atIndex: i-1);
                break;
            }
        }
    }
    
    func deleteStroke(stroke:Stroke)->Bool{
        for (key, var strokeList) in allStrokes{
            for i in 0..<strokeList.count {
                let s = strokeList[i];
                print("id check \(i,s.id,stroke.id,strokeList.count)");
                if s.id == stroke.id{
                    strokeList.removeAtIndex(i)
                    allStrokes[key] = strokeList;
                    bakeQueue[key] = bakeQueue[key]!.filter{$0.id == stroke.id}
                    print("id check \(i,s.id,stroke.id,strokeList.count, bakeQueue[key]!.count)");
                    for j in 0..<self.toSendBake.count{
                        if(self.toSendBake[j] == stroke){
                            toSendBake.removeAtIndex(j);
                            break;
                        }
                    }
                    return true;
                }
            }
        }
        
        
        return false;
    }
    
    
    
    /*func bake(parentID:String){
     var source_string = "[";
     if(bakeQueue[parentID] != nil){
     var bq = bakeQueue[parentID]!
     for i in 0..<bq.count{
     var source = bq[i].gCodeGenerator.source;
     for j in 0..<source.count{
     if(j>0){
     source_string += ","
     }
     source_string += "\""+source[j]+"\""
     }
     
     //source_string += "]"
     source_string += ",\""+gCodeGenerator.endSegment(bakeQueue[parentID]![i].segments[bakeQueue[parentID]![i].segments.count-1])+"\"]"
     bakedStrokes[parentID]!.append(bq[i]);
     }
     bakeQueue[parentID]?.removeAll();
     var data = "\"drawing_id\":\""+self.id+"\","
     data += "\"type\":\"gcode\","
     data += "\"data\":"+source_string
     self.transmitEvent.raise((data));
     print("source",data);
     }
     }*/
    
    
    func checkBake(x:Float,y:Float,z:Float){
        for stroke in  bakedStrokes{
            
            let hit = stroke.hitTest(Point(x:x,y:y), threshold: 5)
            if(hit != nil){
                self.geometryModified.raise((hit!,"SEGMENT","BAKE_DRAW"))
                return;
            }
            
        }
    }
    
    /*func jogAndBake(parentID:String){
     
     var source_string = "[";
     var bq = bakeQueue[parentID]!
     for i in 0..<bq.count{
     var source = bq[i].gCodeGenerator.source;
     var segments = bq[i].segments;
     print("segments=\(segments)");
     let _x = Numerical.map(segments[0].point.x.get(nil), istart:GCodeGenerator.pX, istop: 0, ostart: GCodeGenerator.inX, ostop: 0)
     
     let _y = Numerical.map(segments[0].point.y.get(nil), istart:0, istop:GCodeGenerator.pY, ostart:  GCodeGenerator.inY, ostop: 0 )
     
     source_string += "\""+bq[i].gCodeGenerator.jog3(_x,y:_y,z: GCodeGenerator.retractHeight)+"\"";
     for j in 0..<source.count{
     
     source_string += ",\""+source[j]+"\""
     }
     
     source_string+=",\""+gCodeGenerator.endSegment(segments[segments.count-1])+"\"]"
     bakedStrokes[parentID]!.append(bq[i]);
     }
     bakeQueue[parentID]?.removeAll();
     var data = "\"drawing_id\":\""+self.id+"\","
     data += "\"type\":\"gcode\","
     data += "\"data\":"+source_string
     self.transmitEvent.raise((data));
     print("source",data);
     
     }*/
    
    func transmitJogEvent(data:String){
        var source_string = "[";
        source_string+=data+"]"
        var data = "\"drawing_id\":\""+self.id+"\","
        data += "\"type\":\"gcode\","
        data += "\"data\":"+source_string
        print("jog data to transmit = \(data)");
        self.transmitEvent.raise((data));
    }
    
}


// MARK: Equatable
func ==(lhs:Drawing, rhs:Drawing) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}


