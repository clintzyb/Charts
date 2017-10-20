//
//  BMFLineChartView.swift
//  Charts
//
//  Created by zhu yuanbin on 2017/10/20.
//

import Foundation
import CoreGraphics
// 继承LineChartView用于重写initialize 为了 renderer实现自己定义的render
open class BMFLineChartView: LineChartView {
    
    
    internal var _longPressGestureReconginzer:UILongPressGestureRecognizer!
    fileprivate var _highlightPerLongPressEnabled = true
    fileprivate weak var _outerScrollView: NSUIScrollView?

    open var highlightPerLongPressEnabled:Bool{
        
        get { return _highlightPerLongPressEnabled}
        set {_highlightPerLongPressEnabled = newValue}
    }
    
    open var isHightlightPerLongPressEnabled:Bool{
        
        return highlightPerLongPressEnabled
    }

    override func initialize() {
        super.initialize()
        renderer = BMFLineChartRenderer(dataProvider: self, animator: _animator, viewPortHandler: _viewPortHandler)
        // 朱元斌 2017-08-17 添加
        _longPressGestureReconginzer = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureRecongnized(_:)))
    }
    
    
    
    
    
    open override func gestureRecognizer(_ gestureRecognizer: NSUIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSUIGestureRecognizer) -> Bool
    {
        #if !os(tvOS)
            if ((gestureRecognizer.isKind(of: NSUIPinchGestureRecognizer.self) &&
                otherGestureRecognizer.isKind(of: NSUIPanGestureRecognizer.self)) ||
                (gestureRecognizer.isKind(of: NSUIPanGestureRecognizer.self) &&
                    otherGestureRecognizer.isKind(of: NSUIPinchGestureRecognizer.self)))
            {
                return true
            }
            // 朱元斌2017-08-17 添加用于响应多手势
            if((gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) && otherGestureRecognizer.isKind(of: UILongPressGestureRecognizer.self))){
                
                return true
            }
            
        #endif
        
        if (gestureRecognizer.isKind(of: NSUIPanGestureRecognizer.self) &&
            otherGestureRecognizer.isKind(of: NSUIPanGestureRecognizer.self) && (
                gestureRecognizer == _panGestureRecognizer
            ))
        {
            var scrollView = self.superview
            while (scrollView !== nil && !scrollView!.isKind(of: NSUIScrollView.self))
            {
                scrollView = scrollView?.superview
            }
            
            // If there is two scrollview together, we pick the superview of the inner scrollview.
            // In the case of UITableViewWrepperView, the superview will be UITableView
            if let superViewOfScrollView = scrollView?.superview
                , superViewOfScrollView.isKind(of: NSUIScrollView.self)
            {
                scrollView = superViewOfScrollView
            }
            
            var foundScrollView = scrollView as? NSUIScrollView
            
            if foundScrollView !== nil && !foundScrollView!.nsuiIsScrollEnabled
            {
                foundScrollView = nil
            }
            
            var scrollViewPanGestureRecognizer: NSUIGestureRecognizer!
            
            if foundScrollView !== nil
            {
                for scrollRecognizer in foundScrollView!.nsuiGestureRecognizers!
                {
                    if scrollRecognizer.isKind(of: NSUIPanGestureRecognizer.self)
                    {
                        scrollViewPanGestureRecognizer = scrollRecognizer as! NSUIPanGestureRecognizer
                        break
                    }
                }
            }
            
            if otherGestureRecognizer === scrollViewPanGestureRecognizer
            {
                _outerScrollView = foundScrollView
                
                return true
            }
        }
        
        return false
    }
    
    
    @objc fileprivate  func longPressGestureRecongnized(_ recognizer:UILongPressGestureRecognizer){
        if _data === nil
        {
            return
        }
        
        if recognizer.state == UIGestureRecognizerState.began
        {
            if !self.isHightlightPerLongPressEnabled{
                return
            }
            
            let h = getHighlightByTouchPoint(recognizer.location(in: self))
            
            if h === nil || h!.isEqual(self.lastHighlighted)
            {
                self.highlightValue(nil, callDelegate: true)
                self.lastHighlighted = nil
            }
            else
            {
                self.highlightValue(h, callDelegate: true)
                self.lastHighlighted = h
            }
        }
        else if UIGestureRecognizerState.changed == recognizer.state{
            
            print("状态改变")
            
        }
        else if recognizer.state == UIGestureRecognizerState.ended || recognizer.state == UIGestureRecognizerState.cancelled {
            
            if (delegate != nil) {
                delegate!.charViewLongPressGestureEndOrCancelled(self)
            }
        }
        
    }

}

// 协议扩展
extension ChartViewDelegate{
    
    func charViewLongPressGestureEndOrCancelled(_ charView:ChartViewBase){
        
    }
    
    func chartViewPanGustureEndOrCancelled(_ chartView: ChartViewBase){
        
    }
    
}

