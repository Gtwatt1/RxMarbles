//
//  ViewController.swift
//  RxMarbles
//
//  Created by Roman Tutubalin on 06.01.16.
//  Copyright © 2016 Roman Tutubalin. All rights reserved.
//

import UIKit
import SpriteKit
import RxSwift
import RxCocoa

struct ColoredType: Equatable {
    var value: Int
    var color: UIColor
}

struct TimelineImage {
    static var timeLine: UIImage { return UIImage(named: "timeLine")! }
    static var cross: UIImage { return UIImage(named: "cross")! }
}

func ==(lhs: ColoredType, rhs: ColoredType) -> Bool {
    return lhs.value == rhs.value && lhs.color == rhs.color
}

typealias RecordedType = Recorded<Event<ColoredType>>

class EventView: UIView {
    private var _recorded = RecordedType(time: 0, event: .Completed)
    private weak var _animator: UIDynamicAnimator? = nil
    private var _snap: UISnapBehavior? = nil
    private weak var _timeLine: UIView?
    
    init(recorded: RecordedType) {
        
        switch recorded.value {
        case let .Next(v):
            super.init(frame: CGRectMake(0, 0, 38, 38))
            center = CGPointMake(CGFloat(recorded.time), bounds.height)
            layer.cornerRadius = bounds.width / 2.0
            clipsToBounds = true
            backgroundColor = v.color
            layer.borderColor = UIColor.lightGrayColor().CGColor
            layer.borderWidth = 0.5
            
            let label = UILabel(frame: frame)
            label.textAlignment = .Center
            label.text = "1"
            addSubview(label)
            
        case .Completed:
            super.init(frame: CGRectMake(0, 0, 37, 38))
            center = CGPointMake(CGFloat(recorded.time), bounds.height)
            
            let grayLine = UIView(frame: CGRectMake(17, 5, 3, 28))
            grayLine.backgroundColor = .grayColor()
            
            addSubview(grayLine)
            
            bringSubviewToFront(self)
        case .Error:
            super.init(frame: CGRectMake(0, 0, 37, 38))
            center = CGPointMake(CGFloat(recorded.time), bounds.height)
            
            let firstLineCross = UIView(frame: CGRectMake(10, 7.5, 3, 23))
            firstLineCross.backgroundColor = .grayColor()
            firstLineCross.transform = CGAffineTransformMakeRotation(CGFloat(M_PI * 0.25))
            addSubview(firstLineCross)
            
            let secondLineCross = UIView(frame: CGRectMake(10, 7.5, 3, 23))
            secondLineCross.backgroundColor = .grayColor()
            secondLineCross.transform = CGAffineTransformMakeRotation(CGFloat(M_PI * 0.75))
            addSubview(secondLineCross)
            
            bringSubviewToFront(self)
        }
        
        _recorded = recorded
    }
    
    func use(animator: UIDynamicAnimator?, timeLine: UIView?) {
        if let snap = _snap {
            _animator?.removeBehavior(snap)
        }
        _animator = animator
        _timeLine = timeLine
        if let timeLine = timeLine {
            center.y = timeLine.bounds.height / 2
        }

        _snap = UISnapBehavior(item: self, snapToPoint: CGPointMake(CGFloat(_recorded.time), center.y))
        userInteractionEnabled = _animator != nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

class TimelineView: UIView {
    var _sourceEvents = [EventView]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let timeArrow = UIImageView(image: TimelineImage.timeLine)
        timeArrow.frame = CGRectMake(0, 0, self.bounds.width, TimelineImage.timeLine.size.height)
        timeArrow.center.y = self.center.y
        self.addSubview(timeArrow)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SourceTimelineView: TimelineView {
    
    private let _panGestureRecognizer = UIPanGestureRecognizer()
    private var _panEventView: EventView?
    private var _ghostEventView: EventView?
    
    init(frame: CGRect, resultTimeline: ResultTimelineView) {
        super.init(frame: frame)
        userInteractionEnabled = true
        clipsToBounds = false
        
        addGestureRecognizer(_panGestureRecognizer)
        
        _ = _panGestureRecognizer.rx_event
            .subscribeNext { [weak self] r in
                
                if r.state == .Began {
                    let location = r.locationInView(self)

                    if let i = self!._sourceEvents.indexOf({ $0.frame.contains(location) }) {
                        self!._panEventView = self!._sourceEvents[i]
                    }
                    if self!._panEventView != nil {
                        let snap = self!._panEventView?._snap
                        self!._panEventView?._animator?.removeBehavior(snap!)
                    }
                }
                
                if r.state == .Changed {
                    if self!._ghostEventView != nil {
                        self!._ghostEventView?.removeFromSuperview()
                        self!._ghostEventView = nil
                    }
                    
                    if self!._panEventView != nil {
                        self!._ghostEventView = EventView(recorded: self!._panEventView!._recorded)
                        self!._ghostEventView?.alpha = 0.2
                        self!._ghostEventView?.center.y = self!.bounds.height / 2
                        self!.addSubview(self!._ghostEventView!)
                        
                        self!._panEventView?.center = r.locationInView(self)
                        let time = Int(r.locationInView(self).x)
                        self!._panEventView?._recorded = RecordedType(time: time, event: (self!._panEventView?._recorded.value)!)
                        resultTimeline.updateEvents(self!._sourceEvents)
                    }
                }
                
                if r.state == .Ended {
                    if self!._ghostEventView != nil {
                        self!._ghostEventView?.removeFromSuperview()
                        self!._ghostEventView = nil
                    }
                    
                    if self!._panEventView != nil {
                        let time = Int(r.locationInView(self).x)
                        let snap = self!._panEventView?._snap
                        snap!.snapPoint.x = CGFloat(time + 10)
                        snap!.snapPoint.y = self!.center.y
                        self!._panEventView?._animator?.addBehavior(snap!)
                        self!._panEventView?.superview?.bringSubviewToFront(self!._panEventView!)
                        self!._sourceEvents.forEach({ (eventView) -> () in
                            switch eventView._recorded.value {
                            case .Completed:
                                eventView.superview!.bringSubviewToFront(eventView)
                            case .Error:
                                eventView.superview!.bringSubviewToFront(eventView)
                            default:
                                break
                            }
                        })
                        self!._panEventView?._recorded = RecordedType(time: time, event: (self!._panEventView?._recorded.value)!)
                    }
                    self!._panEventView = nil
                    resultTimeline.updateEvents(self!._sourceEvents)
                }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ResultTimelineView: TimelineView {
    
    private var _operator: Operator!
    
    init(frame: CGRect, currentOperator: Operator) {
        super.init(frame: frame)
        _operator = currentOperator
    }
    
    func updateEvents(sourceEvents: [EventView]) {
        let scheduler = TestScheduler(initialClock: 0)
        let events = sourceEvents.map({ $0._recorded })
        let t = scheduler.createColdObservable(events)
        let o = _operator.map(t.asObservable(), scheduler: scheduler)
        let res = scheduler.start(0, subscribed: 0, disposed: Int(frame.width)) {
            return o
        }
        
        print(res.events)
        addEventsToTimeline(res.events)
    }
    
    func addEventsToTimeline(events: [RecordedType]) {
        _sourceEvents.forEach { (eventView) -> () in
            eventView.removeFromSuperview()
        }

        _sourceEvents.removeAll()
        
        events.forEach { (event) -> () in
            let eventView = EventView(recorded: RecordedType(time: event.time, event: event.value))
            eventView.center.y = self.bounds.height / 2
            _sourceEvents.append(eventView)
        }

        _sourceEvents.forEach { (eventView) -> () in
            self.addSubview(eventView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

class SceneView: UIView {
    var animator: UIDynamicAnimator?
    var _sourceTimeline: TimelineView!
    var _resultTimeline: ResultTimelineView!
    
    init() {
        super.init(frame: CGRectZero)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ViewController: UIViewController {
    private var _currentOperator = Operator.Delay
    private var _operatorTableViewController: OperatorTableViewController?
    
    private var _sceneView: SceneView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .whiteColor()
        
        let addButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: "addElement")
        self.navigationItem.leftBarButtonItem = addButton
        
        let operatorButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Edit, target: self, action: "showOperatorView")
        self.navigationItem.rightBarButtonItem = operatorButton
    }
    
    override func viewWillAppear(animated: Bool) {
        if let newOperator = _operatorTableViewController?.selectedOperator {
            _currentOperator = newOperator
        }
        title = _currentOperator.description
        
        if _sceneView != nil {
            _sceneView.removeFromSuperview()
        }
        
        _sceneView = SceneView()
        setupSceneView()
    }
    
    private func setupSceneView() {
        view.addSubview(_sceneView)
        _sceneView.frame = view.frame
        
        _sceneView.animator = UIDynamicAnimator(referenceView: _sceneView)
        
        let resultTimeline = ResultTimelineView(frame: CGRectMake(10, 0, _sceneView.bounds.width - 20, 40), currentOperator: _currentOperator)
        resultTimeline.center.y = 200
        _sceneView.addSubview(resultTimeline)
        _sceneView._resultTimeline = resultTimeline
        
        let sourceTimeLine = SourceTimelineView(frame: CGRectMake(10, 0, _sceneView.bounds.width - 20, 40), resultTimeline: resultTimeline)
        sourceTimeLine.center.y = 120
        _sceneView.addSubview(sourceTimeLine)
        _sceneView._sourceTimeline = sourceTimeLine
        
        for t in 1..<6 {
            let time = t * 50
            let event = Event.Next(ColoredType(value: t, color: RXMUIKit.randomColor()))
            let v = EventView(recorded: RecordedType(time: time, event: event))
            sourceTimeLine.addSubview(v)
            v.use(_sceneView.animator, timeLine: sourceTimeLine)
            sourceTimeLine._sourceEvents.append(v)
        }
        
        let v = EventView(recorded: RecordedType(time: Int(sourceTimeLine.bounds.size.width - 60.0), event: .Completed))
        sourceTimeLine.addSubview(v)
        v.use(_sceneView.animator, timeLine: sourceTimeLine)
        sourceTimeLine._sourceEvents.append(v)
        
        let error = NSError(domain: "com.anjlab.RxMarbles", code: 100500, userInfo: nil)
        let e = EventView(recorded: RecordedType(time: Int(sourceTimeLine.bounds.size.width - 100.0), event: .Error(error)))
        sourceTimeLine.addSubview(e)
        e.use(_sceneView.animator, timeLine: sourceTimeLine)
        sourceTimeLine._sourceEvents.append(e)
        
        resultTimeline.updateEvents(sourceTimeLine._sourceEvents)
    }
    
    func addElement() {
        let sourceTimeline = _sceneView._sourceTimeline
        let resultTimeline = _sceneView._resultTimeline
        let time = 100
        
        let elementSelector = UIAlertController(title: "Select operator", message: nil, preferredStyle: .ActionSheet)
        
        let nextAction = UIAlertAction(title: "Next", style: .Default) { (action) -> Void in
            let event = Event.Next(ColoredType(value: 1, color: RXMUIKit.randomColor()))
            let v = EventView(recorded: RecordedType(time: time, event: event))
            sourceTimeline.addSubview(v)
            v.use(self._sceneView.animator, timeLine: sourceTimeline)
            sourceTimeline._sourceEvents.append(v)
            resultTimeline.updateEvents(sourceTimeline._sourceEvents)
        }
        let completedAction = UIAlertAction(title: "Completed", style: .Default) { (action) -> Void in
            let v = EventView(recorded: RecordedType(time: time, event: .Completed))
            sourceTimeline.addSubview(v)
            v.use(self._sceneView.animator, timeLine: sourceTimeline)
            sourceTimeline._sourceEvents.append(v)
            resultTimeline.updateEvents(sourceTimeline._sourceEvents)
        }
        let errorAction = UIAlertAction(title: "Error", style: .Default) { (action) -> Void in
            let error = NSError(domain: "com.anjlab.RxMarbles", code: 100500, userInfo: nil)
            let e = EventView(recorded: RecordedType(time: time, event: .Error(error)))
            sourceTimeline.addSubview(e)
            e.use(self._sceneView.animator, timeLine: sourceTimeline)
            sourceTimeline._sourceEvents.append(e)
            resultTimeline.updateEvents(sourceTimeline._sourceEvents)
        }
        elementSelector.addAction(nextAction)
        elementSelector.addAction(completedAction)
        elementSelector.addAction(errorAction)
        
        presentViewController(elementSelector, animated: true) { () -> Void in }
    }
    
    func showOperatorView() {
        _operatorTableViewController = OperatorTableViewController()
        _operatorTableViewController?.selectedOperator = _currentOperator
        _operatorTableViewController?.title = "Select Operator"
        navigationController?.pushViewController(_operatorTableViewController!, animated: true)
    }
}