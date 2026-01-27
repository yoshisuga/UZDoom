//
//  ExampleAlignment.swift
//  zdoom
//
//  Created by Yoshi Sugawara on 8/17/24.
//

import UIKit

class DraggableView: UIView {
    private var initialCenter: CGPoint = .zero
    private var horizontalGuide: UIView!
    private var verticalGuide: UIView!
    private var alignmentThreshold: CGFloat = 10.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .blue
        layer.cornerRadius = 25
        isUserInteractionEnabled = true

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }

        let translation = gesture.translation(in: superview)
        if gesture.state == .began {
            initialCenter = center
            showGuides()
        }

        if gesture.state != .cancelled {
            center = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            updateGuides()
        } else {
            center = initialCenter
        }

        if gesture.state == .ended {
            snapToNearestGuide()
            hideGuides()
        }
    }

    private func showGuides() {
        guard let superview = superview else { return }

        horizontalGuide = UIView(frame: CGRect(x: 0, y: center.y - 1, width: superview.bounds.width, height: 2))
        horizontalGuide.backgroundColor = .gray
        superview.addSubview(horizontalGuide)

        verticalGuide = UIView(frame: CGRect(x: center.x - 1, y: 0, width: 2, height: superview.bounds.height))
        verticalGuide.backgroundColor = .gray
        superview.addSubview(verticalGuide)
    }

    private func hideGuides() {
        horizontalGuide?.removeFromSuperview()
        verticalGuide?.removeFromSuperview()
    }

    private func updateGuides() {
        guard let superview = superview else { return }

        var horizontalAligned = false
        var verticalAligned = false

        for subview in superview.subviews where subview !== self {
            if abs(center.y - subview.center.y) < alignmentThreshold {
                horizontalAligned = true
                horizontalGuide.frame.origin.y = subview.center.y - 1
            }

            if abs(center.x - subview.center.x) < alignmentThreshold {
                verticalAligned = true
                verticalGuide.frame.origin.x = subview.center.x - 1
            }
        }

        horizontalGuide.isHidden = !horizontalAligned
        verticalGuide.isHidden = !verticalAligned
    }

    private func snapToNearestGuide() {
        guard let superview = superview else { return }

        for subview in superview.subviews where subview !== self {
            if abs(center.y - subview.center.y) < alignmentThreshold {
                center.y = subview.center.y
            }

            if abs(center.x - subview.center.x) < alignmentThreshold {
                center.x = subview.center.x
            }
        }
    }
}

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let draggableView = DraggableView(frame: CGRect(x: 100, y: 100, width: 50, height: 50))
        view.addSubview(draggableView)

        // Add other subviews for alignment reference
        let referenceView1 = UIView(frame: CGRect(x: 200, y: 200, width: 50, height: 50))
        referenceView1.backgroundColor = .red
        view.addSubview(referenceView1)

        let referenceView2 = UIView(frame: CGRect(x: 300, y: 300, width: 50, height: 50))
        referenceView2.backgroundColor = .green
        view.addSubview(referenceView2)
    }
}
