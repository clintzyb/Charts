//
//  MyLineRadarRenderer.swift
//  BingMoFang
//
//  Created by zhu yuanbin on 2017/10/9.
//  Copyright © 2017年 leng360. All rights reserved.
//



import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif


open class MyLineRadarRenderer: LineRadarRenderer
{
    open weak var dataProvider: LineChartDataProvider?
    
    public init(dataProvider: LineChartDataProvider?, animator: Animator?, viewPortHandler: ViewPortHandler?)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    open override func drawData(context: CGContext)
    {
        // 返回的是在LBLLineCharView中被设置的 data
        guard let lineData = dataProvider?.lineData else { return }
        
        for i in 0 ..< lineData.dataSetCount
        {
            guard let set = lineData.getDataSetByIndex(i) else { continue }
            
            if set.isVisible
            {
                if !(set is ILineChartDataSet)
                {
                    fatalError("Datasets for LineChartRenderer must conform to ILineChartDataSet")
                }
                
                drawDataSet(context: context, dataSet: set as! ILineChartDataSet)
            }
        }
    }
    
    open func drawDataSet(context: CGContext, dataSet: ILineChartDataSet)
    {
        if dataSet.entryCount < 1
        {
            return
        }
        
        context.saveGState()
        
        context.setLineWidth(dataSet.lineWidth)
        if dataSet.lineDashLengths != nil
        {
            context.setLineDash(phase: dataSet.lineDashPhase, lengths: dataSet.lineDashLengths!)
        }
        else
        {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        
        // if drawing cubic lines is enabled
        switch dataSet.mode
        {
        case .linear: fallthrough
        case .stepped:
            drawLinear(context: context, dataSet: dataSet)
            
        case .cubicBezier:
            // 朱元斌2017-09-11 注释drawCubicBezier 是绘制连续曲线的方法无法分段绘制
            // drawCubicBezier(context: context, dataSet: dataSet)
            
            // 朱元斌2017-09-11 添加用于实现分段绘制
            drawCubicBezierForSegment(context: context, dataSet: dataSet)
            
        case .horizontalBezier:
            drawHorizontalBezier(context: context, dataSet: dataSet)
        }
        
        context.restoreGState()
    }
    
    open func drawCubicBezier(context: CGContext, dataSet: ILineChartDataSet)
    {
        guard
            let dataProvider = dataProvider,
            let animator = animator
            else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if _xBounds.range >= 1
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            
            // Take an extra point from the left, and an extra from the right.
            // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
            // So in the starting `prev` and `cur`, go -2, -1
            // And in the `lastIndex`, add +1
            
            let firstIndex = _xBounds.min + 1
            let lastIndex = _xBounds.min + _xBounds.range
            
            var prevPrev: ChartDataEntry! = nil
            var prev: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 2, 0))
            var cur: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 1, 0))
            var next: ChartDataEntry! = cur
            var nextIndex: Int = -1
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            
            for j in stride(from: firstIndex, through: lastIndex, by: 1)
            {
                prevPrev = prev
                prev = cur
                cur = nextIndex == j ? next : dataSet.entryForIndex(j)
                
                nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
                next = dataSet.entryForIndex(nextIndex)
                
                if next == nil { break }
                
                prevDx = CGFloat(cur.x - prevPrev.x) * intensity
                prevDy = CGFloat(cur.y - prevPrev.y) * intensity
                curDx = CGFloat(next.x - prev.x) * intensity
                curDy = CGFloat(next.y - prev.y) * intensity
                
                cubicPath.addCurve(
                    to: CGPoint(
                        x: CGFloat(cur.x),
                        y: CGFloat(cur.y) * CGFloat(phaseY)),
                    control1: CGPoint(
                        x: CGFloat(prev.x) + prevDx,
                        y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                    control2: CGPoint(
                        x: CGFloat(cur.x) - curDx,
                        y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                    transform: valueToPixelMatrix)
            }
        }
        
        context.saveGState()
        
        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = cubicPath.mutableCopy()
            
            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: _xBounds)
        }
        
        context.beginPath()
        context.addPath(cubicPath)
        context.setStrokeColor(drawingColor.cgColor)
        context.strokePath()
        
        context.restoreGState()
    }
    
    open func drawHorizontalBezier(context: CGContext, dataSet: ILineChartDataSet)
    {
        guard
            let dataProvider = dataProvider,
            let animator = animator
            else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if _xBounds.range >= 1
        {
            var prev: ChartDataEntry! = dataSet.entryForIndex(_xBounds.min)
            var cur: ChartDataEntry! = prev
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            
            for j in stride(from: (_xBounds.min + 1), through: _xBounds.range + _xBounds.min, by: 1)
            {
                prev = cur
                cur = dataSet.entryForIndex(j)
                
                let cpx = CGFloat(prev.x + (cur.x - prev.x) / 2.0)
                
                cubicPath.addCurve(
                    to: CGPoint(
                        x: CGFloat(cur.x),
                        y: CGFloat(cur.y * phaseY)),
                    control1: CGPoint(
                        x: cpx,
                        y: CGFloat(prev.y * phaseY)),
                    control2: CGPoint(
                        x: cpx,
                        y: CGFloat(cur.y * phaseY)),
                    transform: valueToPixelMatrix)
            }
        }
        
        context.saveGState()
        
        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = cubicPath.mutableCopy()
            
            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: _xBounds)
        }
        
        context.beginPath()
        context.addPath(cubicPath)
        context.setStrokeColor(drawingColor.cgColor)
        context.strokePath()
        
        context.restoreGState()
    }
    
    open func drawCubicFill(
        context: CGContext,
        dataSet: ILineChartDataSet,
        spline: CGMutablePath,
        matrix: CGAffineTransform,
        bounds: XBounds)
    {
        guard
            let dataProvider = dataProvider
            else { return }
        
        if bounds.range <= 0
        {
            return
        }
        
        let fillMin = dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0
        
        var pt1 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min + bounds.range)?.x ?? 0.0), y: fillMin)
        var pt2 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min)?.x ?? 0.0), y: fillMin)
        pt1 = pt1.applying(matrix)
        pt2 = pt2.applying(matrix)
        
        spline.addLine(to: pt1)
        spline.addLine(to: pt2)
        spline.closeSubpath()
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: spline, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: spline, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    fileprivate var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
    
    open func drawLinear(context: CGContext, dataSet: ILineChartDataSet)
    {
        guard
            let dataProvider = dataProvider,
            let animator = animator,
            let viewPortHandler = self.viewPortHandler
            else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let invaildiateValue = 0.000001
        
        // 用于存储所有有效数据
        var vailedDataArray = [ChartDataEntry]()
        var values = [ChartDataEntry]()
        
        var before:ChartDataEntry? = nil
        var chartsSegmentArray:[Array<ChartDataEntry>]=[Array<ChartDataEntry>]()
        for index in 0..<dataSet.entryCount{
            
            let e1: ChartDataEntry = dataSet.entryForIndex(index)!
            // 结束条件 当e1 取到无效点时做为一个结束点 当e1 是最后一个点时做为一个结束条件
            if e1.y == invaildiateValue || e1 == dataSet.entryForIndex(dataSet.entryCount-1)!{
                
                // e1 为最后一个点时且为有效点时添加到分段里面去
                if e1 == dataSet.entryForIndex(dataSet.entryCount-1){
                    if e1.y != invaildiateValue{
                        values.append(e1)
                        vailedDataArray.append(e1)
                        before = e1
                    }
                }
                if nil != before{
//                    before?.lastPointSign = true
                    chartsSegmentArray.append(values)
                    values = [ChartDataEntry]()
                    before = nil
                }
                continue
            }
            else{
                before = e1
                values.append(e1)
                vailedDataArray.append(e1)
            }
        }
        // 所有数据为有效数据
        if (vailedDataArray.count == dataSet.entryCount) && (dataSet.entryCount > 0){
            chartsSegmentArray.append(vailedDataArray)
        }
        
        let tempDataSet = dataSet;
        
        let dataSet: LineChartDataSet = LineChartDataSet.init(values: vailedDataArray, label: nil)
        dataSet.drawVerticalHighlightIndicatorEnabled = tempDataSet.drawVerticalHighlightIndicatorEnabled
        dataSet.lineWidth = tempDataSet.lineWidth
        dataSet.mode = tempDataSet.mode
        dataSet.circleRadius = tempDataSet.circleRadius
        dataSet.fillAlpha = tempDataSet.fillAlpha
        dataSet.fill = tempDataSet.fill
        dataSet.drawFilledEnabled  = tempDataSet.drawFilledEnabled
        dataSet.drawValuesEnabled = tempDataSet.drawValuesEnabled
        dataSet.drawCirclesEnabled = tempDataSet.drawCirclesEnabled
        dataSet.circleColors = tempDataSet.circleColors
        dataSet.colors = tempDataSet.colors
        
        dataSet.fillColor = tempDataSet.fillColor
        
        let entryCount = dataSet.entryCount
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2
        let phaseY = animator.phaseY
        
        
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        // if drawing filled is enabled
        if dataSet.isDrawFilledEnabled && entryCount > 0
        {
            // 朱元斌2017-08-18 用于分段绘制 阴影
            for index in 0..<chartsSegmentArray.count{
                
                let charEntryValues = chartsSegmentArray[index];
                let tempDataSets: LineChartDataSet = LineChartDataSet.init(values: charEntryValues, label: nil)
                tempDataSets.fillAlpha = 1.0
                tempDataSets.fill = Fill.fillWithColor(UIColor.init(red: 72.0/255.0, green: 192.0/255.0, blue: 218.0/255.0, alpha: 1.0))
                tempDataSets.fillColor = UIColor.init(red: 218.0/255.0, green: 242.0/255.0, blue: 248.0/255.0, alpha: 1.0)
                // 必须要从新设置bound
                _xBounds.set(chart: dataProvider, dataSet: tempDataSets, animator: animator)
                
                
                drawLinearFill(context: context, dataSet: tempDataSets, trans: trans, bounds: _xBounds)
                
                
            }
            
        }
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        context.saveGState()
        
        context.setLineCap(dataSet.lineCapType)
        
        // more than 1 color
        if dataSet.colors.count > 1
        {
            if _lineSegments.count != pointsPerEntryPair
            {
                // Allocate once in correct size
                _lineSegments = [CGPoint](repeating: CGPoint(), count: pointsPerEntryPair)
            }
            
            for j in stride(from: _xBounds.min, through: _xBounds.range + _xBounds.min, by: 1)
            {
                var e: ChartDataEntry! = dataSet.entryForIndex(j)
                
                if e == nil { continue }
                
                _lineSegments[0].x = CGFloat(e.x)
                _lineSegments[0].y = CGFloat(e.y * phaseY)
                
                if j < _xBounds.max
                {
                    e = dataSet.entryForIndex(j + 1)
                    
                    if e == nil { break }
                    
                    if isDrawSteppedEnabled
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: _lineSegments[0].y)
                        _lineSegments[2] = _lineSegments[1]
                        _lineSegments[3] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                    else
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                }
                else
                {
                    _lineSegments[1] = _lineSegments[0]
                }
                
                for i in 0..<_lineSegments.count
                {
                    _lineSegments[i] = _lineSegments[i].applying(valueToPixelMatrix)
                }
                
                if (!viewPortHandler.isInBoundsRight(_lineSegments[0].x))
                {
                    break
                }
                
                // make sure the lines don't do shitty things outside bounds
                if !viewPortHandler.isInBoundsLeft(_lineSegments[1].x)
                    || (!viewPortHandler.isInBoundsTop(_lineSegments[0].y) && !viewPortHandler.isInBoundsBottom(_lineSegments[1].y))
                {
                    continue
                }
                
                // get the color that is set for this line-segment
                context.setStrokeColor(dataSet.color(atIndex: j).cgColor)
                context.strokeLineSegments(between: _lineSegments)
            }
        }
        else
        { // only one color per dataset
            
            var e1: ChartDataEntry!
            var e2: ChartDataEntry!
            
            e1 = dataSet.entryForIndex(_xBounds.min)
            
            if e1 != nil
            {
                context.beginPath()
                //                var firstPoint = true
                
                
                for index in 0..<chartsSegmentArray.count{
                    
                    let chartEntryArray = chartsSegmentArray[index]
                    var firstPoint = true
                    for x in 0..<chartEntryArray.count{
                        e1 = chartEntryArray[x == 0 ? 0 : (x - 1)]
                        e2 = chartEntryArray[x]
                        
                        if e1 == nil || e2 == nil { continue }
                        
                        let pt = CGPoint(
                            x: CGFloat(e1.x),
                            y: CGFloat(e1.y * phaseY)
                            ).applying(valueToPixelMatrix)
                        
                        if firstPoint
                        {
                            context.move(to: pt)
                            firstPoint = false
                        }
                        else
                        {
                            context.addLine(to: pt)
                        }
                        
                        if isDrawSteppedEnabled
                        {
                            context.addLine(to: CGPoint(
                                x: CGFloat(e2.x),
                                y: CGFloat(e1.y * phaseY)
                                ).applying(valueToPixelMatrix))
                        }
                        
                        
                        context.addLine(to: CGPoint(
                            x: CGFloat(e2.x),
                            y: CGFloat(e2.y * phaseY)
                            ).applying(valueToPixelMatrix))
                        
                    }
                    if !firstPoint
                    {
                        context.setStrokeColor(dataSet.color(atIndex: 0).cgColor)
                        context.strokePath()
                    }
                    
                }
                
                //                朱元斌2017-8-017 以下代码用于绘制连续折线
                //                for x in stride(from: _xBounds.min, through: _xBounds.range + _xBounds.min, by: 1)
                //                {
                //                    e1 = dataSet.entryForIndex(x == 0 ? 0 : (x - 1))
                //                    e2 = dataSet.entryForIndex(x)
                //
                //                    if e1 == nil || e2 == nil { continue }
                ////                    let isConnectLine = (false == e1.lastPointSign && true == e2.lastPointSign)
                //
                //                    let pt = CGPoint(
                //                        x: CGFloat(e1.x),
                //                        y: CGFloat(e1.y * phaseY)
                //                        ).applying(valueToPixelMatrix)
                //
                //                    if firstPoint
                //                    {
                //                        context.move(to: pt)
                //                        firstPoint = false
                //                    }
                //                    else
                //                    {
                //                        context.addLine(to: pt)
                //                    }
                //
                //                    if isDrawSteppedEnabled
                //                    {
                //                        context.addLine(to: CGPoint(
                //                            x: CGFloat(e2.x),
                //                            y: CGFloat(e1.y * phaseY)
                //                            ).applying(valueToPixelMatrix))
                //                    }
                //
                //
                //                    context.addLine(to: CGPoint(
                //                            x: CGFloat(e2.x),
                //                            y: CGFloat(e2.y * phaseY)
                //                            ).applying(valueToPixelMatrix))
                //
                //                }
                //                if !firstPoint
                //                {
                //                    context.setStrokeColor(dataSet.color(atIndex: 0).cgColor)
                //                    context.strokePath()
                //                }
            }
        }
        
        context.restoreGState()
    }
    
    open func drawLinearFill(context: CGContext, dataSet: ILineChartDataSet, trans: Transformer, bounds: XBounds)
    {
        guard let dataProvider = dataProvider else { return }
        
        let filled = generateFilledPath(
            dataSet: dataSet,
            fillMin: dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0,
            bounds: bounds,
            matrix: trans.valueToPixelMatrix)
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: filled, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: filled, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    /// Generates the path that is used for filled drawing.
    fileprivate func generateFilledPath(dataSet: ILineChartDataSet, fillMin: CGFloat, bounds: XBounds, matrix: CGAffineTransform) -> CGPath
    {
        let phaseY = animator?.phaseY ?? 1.0
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let matrix = matrix
        
        var e: ChartDataEntry!
        
        let filled = CGMutablePath()
        
        e = dataSet.entryForIndex(bounds.min)
        if e != nil
        {
            filled.move(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // create a new path
        for x in stride(from: (bounds.min + 1), through: bounds.range + bounds.min, by: 1)
        {
            guard let e = dataSet.entryForIndex(x) else { continue }
            
            if isDrawSteppedEnabled
            {
                guard let ePrev = dataSet.entryForIndex(x-1) else { continue }
                filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(ePrev.y * phaseY)), transform: matrix)
            }
            
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // close up
        e = dataSet.entryForIndex(bounds.range + bounds.min)
        if e != nil
        {
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
        }
        filled.closeSubpath()
        
        return filled
    }
    
    open override func drawValues(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData,
            let animator = animator,
            let viewPortHandler = self.viewPortHandler
            else { return }
        
        if isDrawingValuesAllowed(dataProvider: dataProvider)
        {
            var dataSets = lineData.dataSets
            
            let phaseY = animator.phaseY
            
            var pt = CGPoint()
            
            for i in 0 ..< dataSets.count
            {
                guard let dataSet = dataSets[i] as? ILineChartDataSet else { continue }
                
                if !shouldDrawValues(forDataSet: dataSet)
                {
                    continue
                }
                
                let valueFont = dataSet.valueFont
                
                guard let formatter = dataSet.valueFormatter else { continue }
                
                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                let valueToPixelMatrix = trans.valueToPixelMatrix
                
                let iconsOffset = dataSet.iconsOffset
                
                // make sure the values do not interfear with the circles
                var valOffset = Int(dataSet.circleRadius * 1.75)
                
                if !dataSet.isDrawCirclesEnabled
                {
                    valOffset = valOffset / 2
                }
                
                _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
                
                for j in stride(from: _xBounds.min, through: min(_xBounds.min + _xBounds.range, _xBounds.max), by: 1)
                {
                    guard let e = dataSet.entryForIndex(j) else { break }
                    
                    pt.x = CGFloat(e.x)
                    pt.y = CGFloat(e.y * phaseY)
                    pt = pt.applying(valueToPixelMatrix)
                    
                    if (!viewPortHandler.isInBoundsRight(pt.x))
                    {
                        break
                    }
                    
                    if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y))
                    {
                        continue
                    }
                    
                    if dataSet.isDrawValuesEnabled {
                        ChartUtils.drawText(
                            context: context,
                            text: formatter.stringForValue(
                                e.y,
                                entry: e,
                                dataSetIndex: i,
                                viewPortHandler: viewPortHandler),
                            point: CGPoint(
                                x: pt.x,
                                y: pt.y - CGFloat(valOffset) - valueFont.lineHeight),
                            align: .center,
                            attributes: [NSAttributedStringKey.font: valueFont, NSAttributedStringKey.foregroundColor: dataSet.valueTextColorAt(j)])
                    }
                    
                    if let icon = e.icon, dataSet.isDrawIconsEnabled
                    {
                        ChartUtils.drawImage(context: context,
                                             image: icon,
                                             x: pt.x + iconsOffset.x,
                                             y: pt.y + iconsOffset.y,
                                             size: icon.size)
                    }
                }
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
        drawCircles(context: context)
    }
    
    fileprivate func drawCircles(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData,
            let animator = animator,
            let viewPortHandler = self.viewPortHandler
            else { return }
        
        let phaseY = animator.phaseY
        
        let dataSets = lineData.dataSets
        
        
        
        
        
        var pt = CGPoint()
        var rect = CGRect()
        
        context.saveGState()
        let invaildiateValue = 0.000001
        
        for i in 0 ..< dataSets.count
        {
            guard let dataSet = lineData.getDataSetByIndex(i) as? ILineChartDataSet else { continue }
            
            var values = [ChartDataEntry]()
            
            for index in 0...dataSet.entryCount-1{
                
                let e1: ChartDataEntry = dataSet.entryForIndex(index)!
                if e1.y == invaildiateValue{
                    continue
                }
                else{
                    values.append(e1)
                    
                }
            }
            
            
            let dataSet1: LineChartDataSet = LineChartDataSet.init(values: values, label: nil)
            dataSet1.drawVerticalHighlightIndicatorEnabled = dataSet.drawVerticalHighlightIndicatorEnabled
            dataSet1.lineWidth = dataSet.lineWidth
            dataSet1.mode = dataSet.mode
            dataSet1.circleRadius = dataSet.circleRadius
            dataSet1.fillAlpha = dataSet.fillAlpha
            dataSet1.fill = dataSet.fill
            dataSet1.drawFilledEnabled  = dataSet.drawFilledEnabled
            dataSet1.drawValuesEnabled = dataSet.drawValuesEnabled
            dataSet1.drawCirclesEnabled = dataSet.drawCirclesEnabled
            dataSet1.circleColors = dataSet.circleColors
            dataSet1.colors = dataSet.colors
            dataSet1.fillColor = dataSet.fillColor
            
            
            
            
            
            if !dataSet1.isVisible || !dataSet1.isDrawCirclesEnabled || dataSet1.entryCount == 0
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(forAxis: dataSet1.axisDependency)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            _xBounds.set(chart: dataProvider, dataSet: dataSet1, animator: animator)
            
            let circleRadius = dataSet1.circleRadius
            let circleDiameter = circleRadius * 2.0
            let circleHoleRadius = dataSet1.circleHoleRadius
            let circleHoleDiameter = circleHoleRadius * 2.0
            
            let drawCircleHole = dataSet1.isDrawCircleHoleEnabled &&
                circleHoleRadius < circleRadius &&
                circleHoleRadius > 0.0
            let drawTransparentCircleHole = drawCircleHole &&
                (dataSet1.circleHoleColor == nil ||
                    dataSet1.circleHoleColor == NSUIColor.clear)
            
            for j in stride(from: _xBounds.min, through: _xBounds.range + _xBounds.min, by: 1)
            {
                guard let e = dataSet1.entryForIndex(j) else { break }
                
                pt.x = CGFloat(e.x)
                pt.y = CGFloat(e.y * phaseY)
                pt = pt.applying(valueToPixelMatrix)
                
                if (!viewPortHandler.isInBoundsRight(pt.x))
                {
                    break
                }
                
                // make sure the circles don't do shitty things outside bounds
                if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y))
                {
                    continue
                }
                
                context.setFillColor(dataSet1.getCircleColor(atIndex: j)!.cgColor)
                
                rect.origin.x = pt.x - circleRadius
                rect.origin.y = pt.y - circleRadius
                rect.size.width = circleDiameter
                rect.size.height = circleDiameter
                
                if drawTransparentCircleHole
                {
                    // Begin path for circle with hole
                    context.beginPath()
                    context.addEllipse(in: rect)
                    
                    // Cut hole in path
                    rect.origin.x = pt.x - circleHoleRadius
                    rect.origin.y = pt.y - circleHoleRadius
                    rect.size.width = circleHoleDiameter
                    rect.size.height = circleHoleDiameter
                    context.addEllipse(in: rect)
                    
                    // Fill in-between
                    context.fillPath(using: .evenOdd)
                }
                else
                {
                    context.fillEllipse(in: rect)
                    
                    if drawCircleHole
                    {
                        context.setFillColor(dataSet.circleHoleColor!.cgColor)
                        
                        // The hole rect
                        rect.origin.x = pt.x - circleHoleRadius
                        rect.origin.y = pt.y - circleHoleRadius
                        rect.size.width = circleHoleDiameter
                        rect.size.height = circleHoleDiameter
                        
                        context.fillEllipse(in: rect)
                    }
                }
            }
        }
        
        context.restoreGState()
    }
    
    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData,
            let animator = animator
            else { return }
        
        let chartXMax = dataProvider.chartXMax
        
        context.saveGState()
        
        for high in indices
        {
            guard let set = lineData.getDataSetByIndex(high.dataSetIndex) as? ILineChartDataSet
                , set.isHighlightEnabled
                else { continue }
            
            guard let e = set.entryForXValue(high.x, closestToY: high.y) else { continue }
            
            if !isInBoundsX(entry: e, dataSet: set)
            {
                continue
            }
            
            context.setStrokeColor(set.highlightColor.cgColor)
            context.setLineWidth(set.highlightLineWidth)
            if set.highlightLineDashLengths != nil
            {
                context.setLineDash(phase: set.highlightLineDashPhase, lengths: set.highlightLineDashLengths!)
            }
            else
            {
                context.setLineDash(phase: 0.0, lengths: [])
            }
            
            let x = high.x // get the x-position
            let y = high.y * Double(animator.phaseY)
            
            if x > chartXMax * animator.phaseX
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(forAxis: set.axisDependency)
            
            let pt = trans.pixelForValues(x: x, y: y)
            
            high.setDraw(pt: pt)
            
            // draw the lines
            drawHighlightLines(context: context, point: pt, set: set)
        }
        
        context.restoreGState()
    }
}

// 添加d 用于分段绘制CubicBezier
// 朱元斌2017-09-11 添加
extension MyLineRadarRenderer{
    
    open  func drawCubicBezierForSegment(context: CGContext, dataSet: ILineChartDataSet)
    {
        guard
            let dataProvider = dataProvider,
            let animator = animator
            else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        
        
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        //        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let invaildiateValue = 0.000001
        var cubPathArray:[CGMutablePath] = [CGMutablePath]()
        
        // 用于存储所有有效数据
        var vailedDataArray = [ChartDataEntry]()
        var values = [ChartDataEntry]()
        
        var before:ChartDataEntry? = nil
        var chartsSegmentArray:[Array<ChartDataEntry>]=[Array<ChartDataEntry>]()
        for index in 0..<dataSet.entryCount{
            
            let e1: ChartDataEntry = dataSet.entryForIndex(index)!
            if e1.y == invaildiateValue || e1 == dataSet.entryForIndex(dataSet.entryCount-1){
                
                if e1.y != invaildiateValue{
                    values.append(e1)
                    vailedDataArray.append(e1)
                    before = e1
                }
                
                if nil != before{
//                    before?.lastPointSign = true
                    chartsSegmentArray.append(values)
                    values = [ChartDataEntry]()
                    before = nil
                }
                continue
            }
            else{
                before = e1
                values.append(e1)
                vailedDataArray.append(e1)
            }
        }
        // 所有数据为有效数据
        if vailedDataArray.count == dataSet.entryCount{
            chartsSegmentArray.append(vailedDataArray)
        }
        
        let tempDataSet = dataSet;
        
        let dataSet: LineChartDataSet = LineChartDataSet.init(values: vailedDataArray, label: nil)
        dataSet.drawVerticalHighlightIndicatorEnabled = tempDataSet.drawVerticalHighlightIndicatorEnabled
        dataSet.lineWidth = tempDataSet.lineWidth
        dataSet.mode = tempDataSet.mode
        dataSet.circleRadius = tempDataSet.circleRadius
        dataSet.fillAlpha = tempDataSet.fillAlpha
        dataSet.fill = tempDataSet.fill
        dataSet.drawFilledEnabled  = tempDataSet.drawFilledEnabled
        dataSet.drawValuesEnabled = tempDataSet.drawValuesEnabled
        dataSet.drawCirclesEnabled = tempDataSet.drawCirclesEnabled
        dataSet.circleColors = tempDataSet.circleColors
        dataSet.colors = tempDataSet.colors
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        
        if _xBounds.range >= 0
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            // Take an extra point from the left, and an extra from the right.
            // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
            // So in the starting `prev` and `cur`, go -2, -1
            // And in the `lastIndex`, add +1
            
            
            
            for segmentIndex in 0..<chartsSegmentArray.count{
                
                let datatSegmentArray = chartsSegmentArray[segmentIndex]
                let cubicPath = CGMutablePath()
                let firstIndex = 1
                var prevPrev: ChartDataEntry! = nil
                var prev: ChartDataEntry! = datatSegmentArray[max(firstIndex-2,0)]
                var cur: ChartDataEntry! = datatSegmentArray[max(firstIndex - 1, 0)]
                var next: ChartDataEntry! = cur
                var nextIndex: Int = -1
                if nil == cur{
                    continue
                }
                cubPathArray.append(cubicPath)
                cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
                
                for dataIndex in 0..<datatSegmentArray.count{
                    prevPrev = prev
                    prev = cur
                    cur = nextIndex == dataIndex ? next : datatSegmentArray[dataIndex]
                    
                    nextIndex = dataIndex + 1 < datatSegmentArray.count ? dataIndex + 1 : dataIndex
                    next = datatSegmentArray[nextIndex]
                    
                    if next == nil { break }
                    
                    prevDx = CGFloat(cur.x - prevPrev.x) * intensity
                    prevDy = CGFloat(cur.y - prevPrev.y) * intensity
                    curDx = CGFloat(next.x - prev.x) * intensity
                    curDy = CGFloat(next.y - prev.y) * intensity
                    
                    cubicPath.addCurve(
                        to: CGPoint(
                            x: CGFloat(cur.x),
                            y: CGFloat(cur.y) * CGFloat(phaseY)),
                        control1: CGPoint(
                            x: CGFloat(prev.x) + prevDx,
                            y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                        control2: CGPoint(
                            x: CGFloat(cur.x) - curDx,
                            y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                        transform: valueToPixelMatrix)
                    
                }
                
                context.saveGState()
                context.beginPath()
                context.addPath(cubicPath)
                context.setStrokeColor(drawingColor.cgColor)
                context.strokePath()
                
                
            }
            
            
        }
        
        //        context.saveGState()
        //
        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            
            
            for segmentIndex in 0..<chartsSegmentArray.count{
                let dataSegment = chartsSegmentArray[segmentIndex]
                let tempDataSets: LineChartDataSet = LineChartDataSet.init(values: dataSegment, label: nil)
                tempDataSets.fillAlpha = 1.0
                tempDataSets.fill = Fill.fillWithColor(UIColor.init(red: 72.0/255.0, green: 192.0/255.0, blue: 218.0/255.0, alpha: 1.0))
                tempDataSets.fillColor = UIColor.init(red: 218.0/255.0, green: 242.0/255.0, blue: 248.0/255.0, alpha: 1.0)
                
                _xBounds.set(chart: dataProvider, dataSet: tempDataSets, animator: animator)
                
                var cubip = CGMutablePath()
                if cubPathArray.count > 0{
                    cubip = cubPathArray[segmentIndex]
                    
                }
                else{
                    context.addPath(cubip)
                    
                }
                
                let fillPath = cubip
                drawCubicFill(context: context, dataSet: tempDataSets, spline: fillPath, matrix: valueToPixelMatrix, bounds: _xBounds)
                
                
            }
            
        }
        context.restoreGState()
    }
    
}
