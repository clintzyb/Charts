//
//  BMFLineChartView.swift
//  Charts
//
//  Created by zhu yuanbin on 2017/10/20.
//

import Foundation
import CoreGraphics
// 继承LineChartView用于重写initialize 为了 renderer实现自己定义的render
open class BMFLineChartView: BMFLineChartBaseView,LineChartDataProvider {
    
    override func initialize() {
        super.initialize()
        renderer = BMFLineChartRenderer(dataProvider: self, animator: _animator, viewPortHandler: _viewPortHandler)

    }
    open var lineData: LineChartData? { return _data as? LineChartData }
}


