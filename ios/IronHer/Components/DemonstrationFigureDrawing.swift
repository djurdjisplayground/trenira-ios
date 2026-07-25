import SwiftUI

/// Draws a consistent female athletic silhouette with equipment glued to the hands.
/// Camera is static; motion comes only from joint keyframes.
enum DemonstrationFigureDrawing {
    struct Pose: Equatable {
        /// 0 upright, positive = hinge forward (radians in side view).
        var hipHinge: CGFloat = 0
        /// Vertical hip shift (squat depth), 0…1
        var squatDepth: CGFloat = 0
        var kneeL: CGFloat = 0.08
        var kneeR: CGFloat = 0.08
        /// Arm elevation: 0 = down by side, 1 = fully overhead
        var elevL: CGFloat = 0
        var elevR: CGFloat = 0
        /// Lateral abduction: 0 = beside torso, 1 = out to shoulder height
        var abdL: CGFloat = 0
        var abdR: CGFloat = 0
        /// Elbow flexion 0 straight … 1 fully bent
        var elbowL: CGFloat = 0.15
        var elbowR: CGFloat = 0.15
        /// Horizontal press/fly: 0 open/out, 1 pressed in / up over chest
        var pressL: CGFloat = 0
        var pressR: CGFloat = 0
        /// Walk phase 0…1 for farmer carry
        var walk: CGFloat = 0
        /// Rear-foot elevation for Bulgarian / step-up
        var rearSupport: CGFloat = 0
        /// Split stance amount 0…1
        var split: CGFloat = 0
        /// Torso lean for rows (side)
        var torsoPitch: CGFloat = 0
        /// Lying-only: upper-arm fixed angle; forearm hinges via elbow
        var lyingUpperArm: CGFloat = -.pi / 2
    }

    static func pose(for demonstration: ExerciseDemonstration, phase: CGFloat) -> Pose {
        DemonstrationMotionKeyframes.pose(motion: demonstration.motion, phase: phase)
    }

    static func draw(
        in context: GraphicsContext,
        size: CGSize,
        demonstration: ExerciseDemonstration,
        phase: CGFloat
    ) {
        let pose = pose(for: demonstration, phase: phase)
        let ink = IronHerTheme.primaryText.opacity(0.9)
        let soft = IronHerTheme.primaryText.opacity(0.22)
        let fill = IronHerTheme.primaryText.opacity(0.06)

        let scale = min(size.width, size.height) / 260
        let groundY = size.height * 0.9

        // Quiet ground
        var ground = Path()
        ground.move(to: CGPoint(x: size.width * 0.14, y: groundY))
        ground.addLine(to: CGPoint(x: size.width * 0.86, y: groundY))
        context.stroke(ground, with: .color(soft), lineWidth: 1)

        switch demonstration.framing {
        case .lying:
            drawLying(
                context: context,
                size: size,
                demonstration: demonstration,
                pose: pose,
                scale: scale,
                groundY: groundY,
                ink: ink,
                soft: soft,
                fill: fill
            )
        case .plank:
            drawPlank(
                context: context,
                size: size,
                pose: pose,
                scale: scale,
                groundY: groundY,
                ink: ink,
                soft: soft,
                fill: fill,
                side: false
            )
        case .sidePlank:
            drawPlank(
                context: context,
                size: size,
                pose: pose,
                scale: scale,
                groundY: groundY,
                ink: ink,
                soft: soft,
                fill: fill,
                side: true
            )
        default:
            drawUpright(
                context: context,
                size: size,
                demonstration: demonstration,
                pose: pose,
                scale: scale,
                groundY: groundY,
                ink: ink,
                soft: soft,
                fill: fill
            )
        }
    }

    // MARK: - Upright / hinged / seated

    private static func drawUpright(
        context: GraphicsContext,
        size: CGSize,
        demonstration: ExerciseDemonstration,
        pose: Pose,
        scale: CGFloat,
        groundY: CGFloat,
        ink: Color,
        soft: Color,
        fill: Color
    ) {
        let camera = demonstration.camera
        let cx = size.width * (camera == .side ? 0.55 : 0.5)
        let hipY = size.height * (0.58 + pose.squatDepth * 0.1)
        let hip = CGPoint(x: cx, y: hipY)

        let hinge = pose.hipHinge + pose.torsoPitch
        let torsoLen = 52 * scale
        let shoulder = CGPoint(
            x: hip.x + sin(hinge) * torsoLen * (camera == .side ? 1 : 0.35),
            y: hip.y - cos(hinge) * torsoLen
        )

        // Environment first (machine / cable / step / bench support)
        drawSupports(
            context: context,
            size: size,
            demonstration: demonstration,
            hip: hip,
            shoulder: shoulder,
            scale: scale,
            groundY: groundY,
            soft: soft
        )

        let stance = 14 * scale + pose.split * 26 * scale
        let walkSwing = sin(pose.walk * .pi * 2) * 10 * scale

        let leftKnee = CGPoint(
            x: hip.x - (camera == .side ? 4 * scale : stance) - (demonstration.motion == .farmerCarry ? walkSwing * 0.15 : 0),
            y: hip.y + (26 + pose.kneeL * 16) * scale
        )
        let rightKnee = CGPoint(
            x: hip.x + (camera == .side ? 8 * scale + pose.split * 30 * scale : stance)
                + (demonstration.motion == .farmerCarry ? -walkSwing * 0.15 : 0),
            y: hip.y + (26 + pose.kneeR * 16) * scale - pose.rearSupport * 36 * scale
        )

        let leftFoot = CGPoint(
            x: leftKnee.x + (camera == .side ? 6 * scale : -2 * scale) + (demonstration.motion == .farmerCarry ? walkSwing : 0),
            y: groundY - 1
        )
        let rightFoot = CGPoint(
            x: rightKnee.x + (camera == .side ? 10 * scale : 2 * scale) - (demonstration.motion == .farmerCarry ? walkSwing : 0),
            y: pose.rearSupport > 0.05 ? rightKnee.y + 18 * scale : groundY - 1
        )

        let (leftElbow, leftHand) = armEndpoints(
            shoulder: shoulder,
            elev: pose.elevL,
            abd: pose.abdL,
            elbow: pose.elbowL,
            press: pose.pressL,
            camera: camera,
            side: -1,
            scale: scale,
            hinge: hinge
        )
        let (rightElbow, rightHand) = armEndpoints(
            shoulder: shoulder,
            elev: pose.elevR,
            abd: pose.abdR,
            elbow: pose.elbowR,
            press: pose.pressR,
            camera: camera,
            side: 1,
            scale: scale,
            hinge: hinge
        )

        let line = max(2.6, 3.0 * scale)
        strokePolyline(context, [leftFoot, leftKnee, hip], ink, line)
        strokePolyline(context, [rightFoot, rightKnee, hip], ink, line)

        // Soft clothing torso
        var torso = Path()
        torso.move(to: CGPoint(x: hip.x - 9 * scale, y: hip.y))
        torso.addLine(to: CGPoint(x: shoulder.x - 11 * scale, y: shoulder.y + 4 * scale))
        torso.addLine(to: CGPoint(x: shoulder.x + 11 * scale, y: shoulder.y + 4 * scale))
        torso.addLine(to: CGPoint(x: hip.x + 9 * scale, y: hip.y))
        torso.closeSubpath()
        context.fill(torso, with: .color(fill))
        context.stroke(torso, with: .color(ink.opacity(0.55)), lineWidth: 1)

        strokePolyline(context, [hip, shoulder], ink, line)
        strokePolyline(context, [shoulder, leftElbow, leftHand], ink, line)
        strokePolyline(context, [shoulder, rightElbow, rightHand], ink, line)

        drawHead(context: context, shoulder: shoulder, hinge: hinge, scale: scale, ink: ink, line: line)
        drawProp(
            context: context,
            demonstration: demonstration,
            leftHand: leftHand,
            rightHand: rightHand,
            shoulder: shoulder,
            scale: scale,
            ink: ink,
            soft: soft
        )
    }

    private static func armEndpoints(
        shoulder: CGPoint,
        elev: CGFloat,
        abd: CGFloat,
        elbow: CGFloat,
        press: CGFloat,
        camera: DemonstrationCamera,
        side: CGFloat,
        scale: CGFloat,
        hinge: CGFloat
    ) -> (CGPoint, CGPoint) {
        // Compose a readable 2D arm from elevation + abduction + press.
        let upper = 27 * scale
        let fore = 24 * scale

        let elevAngle: CGFloat
        switch camera {
        case .front:
            // Front: elevation swings arm upward; abduction opens sideways.
            elevAngle = (.pi / 2) - elev * (.pi * 0.95) + side * abd * (.pi / 2) * 0.15
            let baseX = shoulder.x + side * (8 * scale + abd * 34 * scale) * (1 - elev * 0.35)
            let baseY = shoulder.y + cos(elev * .pi) * upper * 0.15 + (1 - elev) * upper * 0.85 - press * 8 * scale
            let elbowPt = CGPoint(
                x: baseX + side * sin(abd * .pi / 2) * upper * 0.35,
                y: baseY - elev * upper * 0.9
            )
            let handAngle = elevAngle + side * (1 - elbow) * 0.2
            let hand = CGPoint(
                x: elbowPt.x + side * sin(abd * .pi / 2 + 0.2) * fore * (0.4 + elbow * 0.2),
                y: elbowPt.y - cos(handAngle) * fore * (0.55 + (1 - elbow) * 0.45) + elbow * 10 * scale
            )
            // Fold forearm when elbow flexes (curl / row finish)
            let folded = CGPoint(
                x: elbowPt.x + (hand.x - elbowPt.x) * (1 - elbow * 0.55),
                y: elbowPt.y + (shoulder.y - elbowPt.y) * elbow * 0.55 + (hand.y - elbowPt.y) * (1 - elbow * 0.35)
            )
            return (elbowPt, folded)
        case .side, .threeQuarter:
            let q = camera == .threeQuarter ? 0.55 : 1.0
            // Side: elevation from +pi/2 (down) toward -pi/2 (up), press brings forward.
            let angle = (.pi / 2) - elev * .pi + press * 0.55 * side * 0 + hinge * 0.15
            let open = abd * 0.35 * side * (1 - q)
            let elbowPt = CGPoint(
                x: shoulder.x + cos(angle) * upper * 0.15 * side + sin(angle - .pi / 2) * upper * q + open * 20 * scale,
                y: shoulder.y + sin(angle) * upper * 0.2 + (1 - elev) * upper * 0.75 - elev * upper * 0.85 - press * 6 * scale
            )
            let bend = elbow
            let hand = CGPoint(
                x: elbowPt.x + cos(angle - bend * 1.1) * fore * 0.2 * side + (1 - elev) * 4 * scale,
                y: elbowPt.y + (1 - bend) * fore * 0.85 - bend * 16 * scale - elev * 4 * scale
            )
            return (elbowPt, hand)
        }
    }

    // MARK: - Lying

    private static func drawLying(
        context: GraphicsContext,
        size: CGSize,
        demonstration: ExerciseDemonstration,
        pose: Pose,
        scale: CGFloat,
        groundY: CGFloat,
        ink: Color,
        soft: Color,
        fill: Color
    ) {
        let benchY = size.height * 0.6
        var bench = Path()
        bench.move(to: CGPoint(x: size.width * 0.16, y: benchY))
        bench.addLine(to: CGPoint(x: size.width * 0.84, y: benchY))
        // bench legs
        bench.move(to: CGPoint(x: size.width * 0.22, y: benchY))
        bench.addLine(to: CGPoint(x: size.width * 0.22, y: groundY - 4))
        bench.move(to: CGPoint(x: size.width * 0.78, y: benchY))
        bench.addLine(to: CGPoint(x: size.width * 0.78, y: groundY - 4))
        context.stroke(bench, with: .color(soft), lineWidth: 1.6)

        let hip = CGPoint(x: size.width * 0.40, y: benchY - 5 * scale)
        let shoulder = CGPoint(x: size.width * 0.62, y: benchY - 8 * scale)
        let head = CGPoint(x: size.width * 0.74, y: benchY - 12 * scale)

        let line = max(2.6, 3.0 * scale)
        // Soft torso fill
        var torso = Path()
        torso.addRoundedRect(
            in: CGRect(x: hip.x - 4 * scale, y: benchY - 16 * scale, width: 34 * scale, height: 14 * scale),
            cornerSize: CGSize(width: 6 * scale, height: 6 * scale)
        )
        context.fill(torso, with: .color(fill))

        strokePolyline(context, [hip, shoulder, head], ink, line)
        let knee = CGPoint(x: hip.x - 28 * scale, y: hip.y + 16 * scale)
        let foot = CGPoint(x: knee.x - 6 * scale, y: groundY - 6)
        strokePolyline(context, [hip, knee, foot], ink, line)

        // Upper arms mostly vertical for skull crusher; more open for fly/press
        let isSkull = demonstration.motion == .skullCrusherDumbbell
            || demonstration.motion == .skullCrusherBarbell
            || demonstration.motion == .skullCrusherEZ
            || demonstration.motion == .skullCrusherCable
        let isFly = demonstration.motion == .chestFlyDumbbell
        let isBridge = demonstration.motion == .hipThrust || demonstration.motion == .singleLegGluteBridge

        if isBridge {
            let bridgeHip = CGPoint(x: size.width * 0.5, y: benchY - 8 * scale - pose.squatDepth * 28 * scale)
            let bridgeShoulder = CGPoint(x: size.width * 0.32, y: benchY - 4 * scale)
            let bridgeKnee = CGPoint(x: size.width * 0.62, y: benchY + 6 * scale)
            let bridgeFoot = CGPoint(x: size.width * 0.72, y: groundY - 4)
            strokePolyline(context, [bridgeShoulder, bridgeHip, bridgeKnee, bridgeFoot], ink, line)
            if demonstration.unilateral {
                let floatKnee = CGPoint(x: bridgeHip.x + 10 * scale, y: bridgeHip.y - 18 * scale)
                strokePolyline(context, [bridgeHip, floatKnee], ink, line)
            }
            drawHead(context: context, shoulder: bridgeShoulder, hinge: .pi / 2, scale: scale, ink: ink, line: line, lying: true)
            return
        }

        let upperLen = 26 * scale
        let foreLen = 22 * scale
        // Elbows above shoulders for skull crusher; wider for fly; above chest for press
        let elbowSpread: CGFloat = isFly ? 34 * scale : (isSkull ? 10 * scale : 22 * scale)
        let elbowHeight = isSkull
            ? (-18 * scale)
            : (-10 * scale - pose.pressL * 16 * scale)

        let leftElbow = CGPoint(x: shoulder.x - elbowSpread, y: shoulder.y + elbowHeight)
        let rightElbow = CGPoint(x: shoulder.x + elbowSpread * 0.15, y: shoulder.y + elbowHeight)
        // For side view we mostly see the near arm clearly; still draw both for dumbbells.
        let nearElbow = CGPoint(x: shoulder.x + 2 * scale, y: shoulder.y - upperLen * (isSkull ? 0.85 : 0.55))

        let handDrop = isSkull
            ? (pose.elbowR * 28 * scale) // toward head/side of head when flexed
            : ((1 - pose.pressR) * 22 * scale)

        let nearHand: CGPoint
        if isSkull {
            // Forearm hinges: extended = hands over shoulders; flexed = toward forehead/side of head
            nearHand = CGPoint(
                x: nearElbow.x + 8 * scale + pose.elbowR * 14 * scale,
                y: nearElbow.y + pose.elbowR * 26 * scale - (1 - pose.elbowR) * 8 * scale
            )
        } else if isFly {
            nearHand = CGPoint(
                x: nearElbow.x + (1 - pose.pressR) * 36 * scale,
                y: nearElbow.y + 8 * scale
            )
        } else {
            // Bench press path: hands over chest → up
            nearHand = CGPoint(
                x: nearElbow.x + 4 * scale,
                y: nearElbow.y - pose.pressR * 28 * scale + handDrop * 0.15
            )
        }

        let farElbow = CGPoint(x: nearElbow.x - 16 * scale, y: nearElbow.y + 2 * scale)
        let farHand = CGPoint(x: nearHand.x - 16 * scale, y: nearHand.y + 1 * scale)

        strokePolyline(context, [shoulder, nearElbow, nearHand], ink, line)
        if demonstration.prop == .dumbbells || demonstration.prop == .barbell || demonstration.prop == .ezBar {
            strokePolyline(context, [shoulder, farElbow, farHand], ink, line * 0.85)
        }

        _ = leftElbow; _ = rightElbow; _ = upperLen; _ = foreLen

        drawHead(context: context, shoulder: head, hinge: 0, scale: scale, ink: ink, line: line, lying: true)
        drawProp(
            context: context,
            demonstration: demonstration,
            leftHand: farHand,
            rightHand: nearHand,
            shoulder: shoulder,
            scale: scale,
            ink: ink,
            soft: soft
        )
    }

    // MARK: - Plank

    private static func drawPlank(
        context: GraphicsContext,
        size: CGSize,
        pose: Pose,
        scale: CGFloat,
        groundY: CGFloat,
        ink: Color,
        soft: Color,
        fill: Color,
        side: Bool
    ) {
        let line = max(2.6, 3.0 * scale)
        if side {
            // Side plank: body as diagonal line on forearm
            let elbow = CGPoint(x: size.width * 0.28, y: groundY - 4)
            let shoulder = CGPoint(x: size.width * 0.32, y: groundY - 34 * scale)
            let hip = CGPoint(x: size.width * 0.55, y: groundY - 36 * scale - pose.squatDepth * 4 * scale)
            let feet = CGPoint(x: size.width * 0.78, y: groundY - 4)
            strokePolyline(context, [elbow, shoulder, hip, feet], ink, line)
            let topArm = CGPoint(x: hip.x - 4 * scale, y: hip.y - 28 * scale)
            strokePolyline(context, [shoulder, topArm], ink, line)
            drawHead(context: context, shoulder: shoulder, hinge: 0, scale: scale, ink: ink, line: line)
            return
        }

        let depth = pose.elbowL // used as push-up depth
        let shoulder = CGPoint(x: size.width * 0.38, y: groundY - 42 * scale + depth * 16 * scale)
        let hip = CGPoint(x: size.width * 0.58, y: groundY - 40 * scale + depth * 14 * scale)
        let feet = CGPoint(x: size.width * 0.78, y: groundY - 4)
        let hands = CGPoint(x: size.width * 0.30, y: groundY - 4)
        let elbow = CGPoint(
            x: (shoulder.x + hands.x) / 2,
            y: shoulder.y + 10 * scale + depth * 8 * scale
        )

        var torso = Path()
        torso.move(to: CGPoint(x: shoulder.x, y: shoulder.y - 5 * scale))
        torso.addLine(to: CGPoint(x: hip.x, y: hip.y - 5 * scale))
        torso.addLine(to: CGPoint(x: hip.x, y: hip.y + 5 * scale))
        torso.addLine(to: CGPoint(x: shoulder.x, y: shoulder.y + 5 * scale))
        torso.closeSubpath()
        context.fill(torso, with: .color(fill))

        strokePolyline(context, [hands, elbow, shoulder, hip, feet], ink, line)
        drawHead(context: context, shoulder: shoulder, hinge: .pi / 2.2, scale: scale, ink: ink, line: line)
        _ = soft
    }

    // MARK: - Shared pieces

    private static func drawHead(
        context: GraphicsContext,
        shoulder: CGPoint,
        hinge: CGFloat,
        scale: CGFloat,
        ink: Color,
        line: CGFloat,
        lying: Bool = false
    ) {
        let headCenter = lying
            ? CGPoint(x: shoulder.x + 2 * scale, y: shoulder.y - 2 * scale)
            : CGPoint(
                x: shoulder.x + sin(hinge) * 14 * scale,
                y: shoulder.y - cos(hinge) * 16 * scale
            )
        let r = 8.5 * scale
        let headRect = CGRect(x: headCenter.x - r, y: headCenter.y - r, width: r * 2, height: r * 2)
        context.stroke(Path(ellipseIn: headRect), with: .color(ink), lineWidth: line * 0.85)

        // Simple ponytail — consistent female cue, never obscures the working limbs.
        var hair = Path()
        hair.move(to: CGPoint(x: headCenter.x - 2 * scale, y: headCenter.y - r * 0.6))
        hair.addQuadCurve(
            to: CGPoint(x: headCenter.x - 12 * scale, y: headCenter.y + 6 * scale),
            control: CGPoint(x: headCenter.x - 14 * scale, y: headCenter.y - 8 * scale)
        )
        context.stroke(hair, with: .color(ink.opacity(0.55)), lineWidth: line * 0.65)
    }

    private static func drawSupports(
        context: GraphicsContext,
        size: CGSize,
        demonstration: ExerciseDemonstration,
        hip: CGPoint,
        shoulder: CGPoint,
        scale: CGFloat,
        groundY: CGFloat,
        soft: Color
    ) {
        switch demonstration.prop {
        case .machine, .smithMachine:
            var frame = Path()
            let left = size.width * 0.22
            let right = size.width * 0.78
            frame.move(to: CGPoint(x: left, y: size.height * 0.16))
            frame.addLine(to: CGPoint(x: left, y: groundY - 2))
            frame.move(to: CGPoint(x: right, y: size.height * 0.16))
            frame.addLine(to: CGPoint(x: right, y: groundY - 2))
            frame.move(to: CGPoint(x: left, y: size.height * 0.28))
            frame.addLine(to: CGPoint(x: right, y: size.height * 0.28))
            if demonstration.prop == .smithMachine {
                // Vertical guided bar rails
                frame.move(to: CGPoint(x: size.width * 0.42, y: size.height * 0.18))
                frame.addLine(to: CGPoint(x: size.width * 0.42, y: groundY - 8))
                frame.move(to: CGPoint(x: size.width * 0.58, y: size.height * 0.18))
                frame.addLine(to: CGPoint(x: size.width * 0.58, y: groundY - 8))
            }
            context.stroke(frame, with: .color(soft), lineWidth: 1.4)
        case .cable, .rope:
            var cable = Path()
            cable.move(to: CGPoint(x: size.width * 0.8, y: size.height * 0.1))
            cable.addLine(to: CGPoint(x: size.width * 0.8, y: shoulder.y))
            context.stroke(cable, with: .color(soft), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        case .bodyweightBar:
            var bar = Path()
            bar.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.14))
            bar.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.14))
            context.stroke(bar, with: .color(soft), lineWidth: 2)
        default:
            break
        }

        if demonstration.framing == .seated {
            var seat = Path()
            seat.move(to: CGPoint(x: hip.x - 30 * scale, y: hip.y + 6 * scale))
            seat.addLine(to: CGPoint(x: hip.x + 26 * scale, y: hip.y + 6 * scale))
            seat.addLine(to: CGPoint(x: hip.x + 26 * scale, y: hip.y + 12 * scale))
            context.stroke(seat, with: .color(soft), lineWidth: 1.5)
        }

        if demonstration.motion == .stepUp || demonstration.motion == .bulgarianSplitSquat {
            var box = Path()
            let x = size.width * (demonstration.motion == .stepUp ? 0.58 : 0.68)
            box.addRect(CGRect(x: x, y: groundY - 34 * scale, width: 36 * scale, height: 34 * scale))
            context.stroke(box, with: .color(soft), lineWidth: 1.4)
        }
    }

    private static func drawProp(
        context: GraphicsContext,
        demonstration: ExerciseDemonstration,
        leftHand: CGPoint,
        rightHand: CGPoint,
        shoulder: CGPoint,
        scale: CGFloat,
        ink: Color,
        soft: Color
    ) {
        let lw = max(1.7, 2.1 * scale)

        func dumbbell(at p: CGPoint) {
            var path = Path()
            // Handle
            path.move(to: CGPoint(x: p.x - 6 * scale, y: p.y))
            path.addLine(to: CGPoint(x: p.x + 6 * scale, y: p.y))
            // Plates
            path.addEllipse(in: CGRect(x: p.x - 11 * scale, y: p.y - 5 * scale, width: 6 * scale, height: 10 * scale))
            path.addEllipse(in: CGRect(x: p.x + 5 * scale, y: p.y - 5 * scale, width: 6 * scale, height: 10 * scale))
            context.stroke(path, with: .color(ink), lineWidth: lw * 0.9)
        }

        func bar(from a: CGPoint, to b: CGPoint, plates: Bool) {
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            context.stroke(path, with: .color(ink), lineWidth: lw)
            if plates {
                for end in [a, b] {
                    var plate = Path()
                    plate.addEllipse(in: CGRect(x: end.x - 3.5 * scale, y: end.y - 9 * scale, width: 7 * scale, height: 18 * scale))
                    context.stroke(plate, with: .color(ink), lineWidth: lw * 0.75)
                }
            }
        }

        switch demonstration.prop {
        case .none, .bench, .bodyweightBar:
            break
        case .dumbbells:
            dumbbell(at: leftHand)
            dumbbell(at: rightHand)
        case .singleDumbbell:
            if demonstration.motion == .overheadTricepTwoHand || demonstration.motion == .gobletSquat {
                let mid = CGPoint(x: (leftHand.x + rightHand.x) / 2, y: min(leftHand.y, rightHand.y))
                dumbbell(at: mid)
            } else {
                dumbbell(at: demonstration.unilateral ? rightHand : leftHand)
            }
        case .kettlebell:
            let p = rightHand
            var path = Path()
            path.addEllipse(in: CGRect(x: p.x - 7 * scale, y: p.y - 1 * scale, width: 14 * scale, height: 14 * scale))
            path.move(to: CGPoint(x: p.x - 5 * scale, y: p.y))
            path.addQuadCurve(to: CGPoint(x: p.x + 5 * scale, y: p.y), control: CGPoint(x: p.x, y: p.y - 9 * scale))
            context.stroke(path, with: .color(ink), lineWidth: lw * 0.9)
        case .barbell, .ezBar, .smithMachine:
            bar(from: leftHand, to: rightHand, plates: demonstration.prop != .ezBar)
        case .cable, .rope:
            var line = Path()
            line.move(to: rightHand)
            line.addLine(to: CGPoint(x: shoulder.x + 48 * scale, y: shoulder.y - 46 * scale))
            context.stroke(line, with: .color(soft.opacity(1)), style: StrokeStyle(lineWidth: lw * 0.7, dash: [2, 2]))
            if demonstration.prop == .rope {
                dumbbell(at: leftHand)
                dumbbell(at: rightHand)
            } else if demonstration.motion == .tricepPushdown || demonstration.motion == .latPulldown {
                bar(from: leftHand, to: rightHand, plates: false)
            }
        case .machine:
            bar(from: leftHand, to: rightHand, plates: false)
        }
    }

    private static func strokePolyline(
        _ context: GraphicsContext,
        _ points: [CGPoint],
        _ color: Color,
        _ width: CGFloat
    ) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }
}
