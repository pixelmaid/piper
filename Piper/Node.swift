//
//  Node.swift
//  DrawPad
//
//  Created by JENNIFER MARY JACOBS on 2/1/16.
//

import Foundation
import UIKit


protocol PropertyObservable {
    typealias PropertyType
    typealias TargetType
    var propertyChanged: Event<(PropertyType,TargetType)> { get }
}

/*protocol NodeObservable {
 typealias PropertyType
 typealias TargetType
 var propertyChanged: Event<(PropertyType,TargetType)> { get }
 }*/
enum NodeProperty {
    case Selected, Name, Linked, Value, Color
}


class ObservableNode: PropertyObservable {
    typealias PropertyType = NodeProperty
    let propertyChanged = Event<(NodeProperty,ObservableNode)>()
    let valueChanged = Event<(NodeProperty,ObservableNode)>()
    let colorChanged = Event<(NodeProperty, UIColor)>()
    let linkCreated = Event<(NodeProperty, Bool)>()

    var color = UIColor.blueColor();
    var outputs = [ObservableNode]();
    
    
    init(name:String){
       self.name = name
    }
    
    func setValue(value:Float){
        
    }
    
    dynamic var name: String = "" {
        didSet {
        propertyChanged.raise((.Name, self))
        }
    }

    
    func addOutput(output:ObservableNode){
        //print(" adding output \(output.name,self.color)")
        output.color = self.color;
        output.colorChanged.raise((.Color, self.color));
        output.linkCreated.raise((.Linked, true));
        self.outputs.append(output);
        
    }
    
    func setColor(color:UIColor){
        self.color = color;
        colorChanged.raise((.Color, self.color));
    }
    
}




class NodeTerminal:ObservableNode {
    typealias PropertyType = NodeProperty
    var oldValue = Float(0)

    override init(name:String){
        super.init(name:name);
    }
    
    dynamic var selected: Bool = false {
        didSet {
        propertyChanged.raise((.Selected,self))
        }
    }
    
    
    
    dynamic var value: Float = 0.0{
        didSet {
        self.oldValue = oldValue
        
        }
    }
    
    override func setValue(value:Float){
        self.value = value;
        valueChanged.raise((.Value,self))
        //print("setting value for \(self.name,self.value)")

        for output in self.outputs {
            output.setValue(self.value)
        }
    }
    
    
    
}

class AdditionNode: Node{
    var value = NodeTerminal(name: "value");
    var addition = NodeTerminal(name: "addition");
    
    override init(name:String){
        super.init(name: name)
        terminals["value"] = value;
        terminals["addition"] = addition;
        addition.value = 0;
        value.value = 0;
        value.valueChanged.addHandler(self, handler:AdditionNode.onValueChanged)
        addition.valueChanged.addHandler(self, handler:AdditionNode.onValueChanged)
        
    }
    
    
    override func onValueChanged(data: (NodeProperty,ObservableNode)){
        valueChanged.raise((.Value,self))
        
        for output in (self as ObservableNode).outputs {
            output.setValue(self.value.value+self.addition.value)
        }
    }
}

class MultiplierNode: Node{
    var value = NodeTerminal(name:"value");
    var multiplier = NodeTerminal(name:"multiplier");
    
    override init(name:String){
        super.init(name: name)
        terminals["value"] = value;
        terminals["multiplier"] = multiplier;
        multiplier.value = 1;
        value.value = 0;
        value.valueChanged.addHandler(self, handler:MultiplierNode.onValueChanged)
        multiplier.valueChanged.addHandler(self, handler:MultiplierNode.onValueChanged)

    }


    override func onValueChanged(data: (NodeProperty,ObservableNode)){
        valueChanged.raise((.Value,self))
        
        for output in (self as ObservableNode).outputs {
            output.setValue(self.value.value*self.multiplier.value)
        }
    }
}

class RepeatNode: Node{
    var count = NodeTerminal(name:"count");
    var limit = NodeTerminal(name:"limit");
    override init(name:String){
        super.init(name: name)
        terminals["count"] = count;
        terminals["limit"] = limit;
        count.value = 0;
        limit.value = 5;
        //count.valueChanged.addHandler(self, handler:RepeatNode.onCountChanged)
    }
    
    override func setValue(value:Float) {
        
           count.setValue(count.value+1)
        //print("repeat node set value, count:\(self.count.value)");
            if(count.value <= limit.value){
                valueChanged.raise((.Value,self))
                for output in (self as ObservableNode).outputs {
                    output.setValue(count.value)
                }
            }
            else{
                count.setValue(0)
            }
        }
   
    
    /*func onCountChanged(data: (NodeProperty,ObservableNode)) {
        print("count changed to \(count.value)")
    }*/
}

class Node: ObservableNode{
    typealias PropertyType = NodeProperty
    var terminals = [String:NodeTerminal]();
    var locked = [String:Bool]();
    var links = 0;
    var linkCount = 0;
    
    override func setValue(value:Float){
        
    }
    
    func addTerminal(name: String, type:String = "standard"){
        var terminal = NodeTerminal(name:name)
        
        terminals[name] = terminal;
        terminal.valueChanged.addHandler(self, handler: Node.onValueChanged)
        terminal.linkCreated.addHandler(self, handler: Node.onLinkCreated);
        locked[name] = false;
    }
    
    
    func updateValue(values:[String:Float]){
        for (key,value) in values{
           self.terminals[key]!.setValue(value);
        }
    }
    
    func onLinkCreated(data:(NodeProperty,Bool)){
        links = links+1
        print("======link count set to \(links)========")

    }
    
    func onValueChanged(data: (NodeProperty,ObservableNode)) {
        if (self.name == "output node 1"){
            print("node updated \(data.1.name)")
        }
        linkCount+=1;
        if(linkCount==links){
             if (self.name == "output node 1"){
            print("======count reached \(linkCount)========")
            }

            valueChanged.raise((.Value,self));
            
            for output in (self as ObservableNode).outputs {
                output.setValue(0)
            }
            linkCount = 0
            
        }
        
        
        
    }
    
}