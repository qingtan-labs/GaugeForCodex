#import <Cocoa/Cocoa.h>
#import <math.h>

static NSColor *QGColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithSRGBRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:alpha];
}

static NSPoint QGPointOnCircle(NSPoint center, CGFloat radius, CGFloat degrees) {
    CGFloat radians = degrees * M_PI / 180.0;
    return NSMakePoint(center.x + cos(radians) * radius,
                       center.y + sin(radians) * radius);
}

static void QGDrawGradientArc(NSPoint center,
                              CGFloat radius,
                              CGFloat lineWidth,
                              CGFloat startAngle,
                              CGFloat endAngle) {
    const NSInteger segments = 64;
    for (NSInteger index = 0; index < segments; index++) {
        CGFloat t0 = (CGFloat)index / segments;
        CGFloat t1 = (CGFloat)(index + 1) / segments;
        CGFloat start = startAngle + (endAngle - startAngle) * t0;
        CGFloat end = startAngle + (endAngle - startAngle) * t1;
        NSBezierPath *segment = [NSBezierPath bezierPath];
        segment.lineWidth = lineWidth;
        segment.lineCapStyle = NSLineCapStyleButt;
        [segment appendBezierPathWithArcWithCenter:center radius:radius
                                        startAngle:start endAngle:end clockwise:YES];
        [QGColor(38.0 + (119.0 - 38.0) * t0,
                 199.0 + (239.0 - 199.0) * t0,
                 255.0 + (143.0 - 255.0) * t0,
                 1.0) setStroke];
        [segment stroke];
    }

    for (NSNumber *angleNumber in @[@(startAngle), @(endAngle)]) {
        CGFloat angle = angleNumber.doubleValue;
        CGFloat t = fabs(angle - startAngle) < 0.01 ? 0.0 : 1.0;
        NSPoint point = QGPointOnCircle(center, radius, angle);
        [QGColor(38.0 + (119.0 - 38.0) * t,
                 199.0 + (239.0 - 199.0) * t,
                 255.0 + (143.0 - 255.0) * t,
                 1.0) setFill];
        CGFloat capRadius = lineWidth / 2.0;
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(point.x - capRadius,
                                                          point.y - capRadius,
                                                          capRadius * 2,
                                                          capRadius * 2)] fill];
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: GenerateGaugeForCodexIcon output.png\n");
            return 2;
        }

        const NSInteger size = 1024;
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:size pixelsHigh:size bitsPerSample:8
            samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
            bytesPerRow:0 bitsPerPixel:0];
        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext = context;
        context.imageInterpolation = NSImageInterpolationHigh;
        [NSColor.clearColor setFill];
        NSRectFill(NSMakeRect(0, 0, size, size));

        NSRect tileRect = NSMakeRect(82, 82, 860, 860);
        NSBezierPath *tile = [NSBezierPath bezierPathWithRoundedRect:tileRect xRadius:216 yRadius:216];
        NSShadow *tileShadow = [NSShadow new];
        tileShadow.shadowColor = QGColor(5, 10, 29, 0.42);
        tileShadow.shadowBlurRadius = 46;
        tileShadow.shadowOffset = NSMakeSize(0, -18);
        [NSGraphicsContext saveGraphicsState];
        [tileShadow set];
        [QGColor(18, 23, 41, 1) setFill];
        [tile fill];
        [NSGraphicsContext restoreGraphicsState];

        NSGradient *tileGradient = [[NSGradient alloc]
            initWithStartingColor:QGColor(16, 22, 40, 1)
                      endingColor:QGColor(47, 53, 86, 1)];
        [tileGradient drawInBezierPath:tile angle:-48];
        tile.lineWidth = 3;
        [QGColor(255, 255, 255, 0.14) setStroke];
        [tile stroke];

        // Quiet radial glow: enough depth at large sizes without adding noise
        // when macOS renders the icon at 16–32 points.
        [NSGraphicsContext saveGraphicsState];
        [tile addClip];
        NSGradient *glow = [[NSGradient alloc]
            initWithStartingColor:QGColor(40, 204, 255, 0.17)
                      endingColor:QGColor(40, 204, 255, 0.0)];
        [glow drawFromCenter:NSMakePoint(306, 744) radius:8
                   toCenter:NSMakePoint(306, 744) radius:520 options:0];
        [NSGraphicsContext restoreGraphicsState];

        NSPoint center = NSMakePoint(512, 518);
        CGFloat gaugeRadius = 316;
        NSBezierPath *track = [NSBezierPath bezierPath];
        track.lineWidth = 34;
        track.lineCapStyle = NSLineCapStyleRound;
        [track appendBezierPathWithArcWithCenter:center radius:gaugeRadius
                                     startAngle:218 endAngle:-38 clockwise:YES];
        [QGColor(255, 255, 255, 0.13) setStroke];
        [track stroke];
        QGDrawGradientArc(center, gaugeRadius, 34, 218, 31);

        NSPoint progressPoint = QGPointOnCircle(center, gaugeRadius, 31);
        [QGColor(21, 27, 47, 1) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(progressPoint.x - 22,
                                                          progressPoint.y - 22,
                                                          44, 44)] fill];
        [NSColor.whiteColor setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(progressPoint.x - 16,
                                                          progressPoint.y - 16,
                                                          32, 32)] fill];
        [QGColor(116, 239, 150, 1) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(progressPoint.x - 9,
                                                          progressPoint.y - 9,
                                                          18, 18)] fill];

        NSShadow *glyphShadow = [NSShadow new];
        glyphShadow.shadowColor = QGColor(0, 0, 0, 0.30);
        glyphShadow.shadowBlurRadius = 9;
        glyphShadow.shadowOffset = NSMakeSize(0, -5);
        [NSGraphicsContext saveGraphicsState];
        [glyphShadow set];
        [NSColor.whiteColor setStroke];

        // Original C + terminal-prompt monogram. The C gives the product a
        // Codex-specific cue without copying or modifying OpenAI artwork.
        NSBezierPath *codexC = [NSBezierPath bezierPath];
        codexC.lineWidth = 55;
        codexC.lineCapStyle = NSLineCapStyleRound;
        [codexC appendBezierPathWithArcWithCenter:NSMakePoint(500, 520)
                                           radius:166
                                       startAngle:43
                                         endAngle:317
                                        clockwise:NO];
        [codexC stroke];

        [QGColor(105, 224, 239, 1) setStroke];
        NSBezierPath *chevron = [NSBezierPath bezierPath];
        chevron.lineWidth = 29;
        chevron.lineCapStyle = NSLineCapStyleRound;
        chevron.lineJoinStyle = NSLineJoinStyleRound;
        [chevron moveToPoint:NSMakePoint(445, 570)];
        [chevron lineToPoint:NSMakePoint(505, 518)];
        [chevron lineToPoint:NSMakePoint(445, 466)];
        [chevron stroke];

        NSBezierPath *cursor = [NSBezierPath bezierPath];
        cursor.lineWidth = 28;
        cursor.lineCapStyle = NSLineCapStyleRound;
        [cursor moveToPoint:NSMakePoint(529, 468)];
        [cursor lineToPoint:NSMakePoint(598, 468)];
        [cursor stroke];
        [NSGraphicsContext restoreGraphicsState];

        [NSGraphicsContext restoreGraphicsState];
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        if (![png writeToFile:path atomically:YES]) {
            fprintf(stderr, "failed to write icon\n");
            return 1;
        }
    }
    return 0;
}
