#import "MGLFoundation_Private.h"
#import "MGLLoggingConfiguration_Private.h"
#import "MGLMapView+Metal.h"

#include <mbgl/gl/renderable_resource.hpp>

#import <MetalKit/MetalKit.h>
//#import <GLKit/GLKit.h>
//#import <OpenGLES/EAGL.h>
//#import <QuartzCore/CAEAGLLayer.h>

@interface MGLMapViewImplDelegate : NSObject <MTKViewDelegate>
@end

@implementation MGLMapViewImplDelegate {
    MGLMapViewMetalImpl* _impl;
}

- (instancetype)initWithImpl:(MGLMapViewMetalImpl*)impl {
    if (self = [super init]) {
        _impl = impl;
    }
    return self;
}

//- (void)mtkView:(nonnull MTKView*)view drawInRect:(CGRect)rect {
//    _impl->render();
//}

- (void)drawInMTKView:(nonnull MTKView *)view {
    _impl->render();
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    
}

@end

namespace {
CGFloat contentScaleFactor() {
    return [UIScreen instancesRespondToSelector:@selector(nativeScale)]
        ? [[UIScreen mainScreen] nativeScale]
        : [[UIScreen mainScreen] scale];
}
} // namespace

class MGLMapViewMetalRenderableResource final : public mbgl::gl::RenderableResource {
public:
    MGLMapViewMetalRenderableResource(MGLMapViewMetalImpl& backend_)
        : backend(backend_),
          delegate([[MGLMapViewImplDelegate alloc] initWithImpl:&backend]),
          atLeastiOS_12_2_0([NSProcessInfo.processInfo
              isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){ 12, 2, 0 }]) {
    }

    void bind() override {
        backend.restoreFramebufferBinding();
    }

//    mbgl::Size framebufferSize() {
//        assert(mtkView);
//        return { static_cast<uint32_t>(mtkView.drawableWidth),
//                 static_cast<uint32_t>(mtkView.drawableHeight) };
//    }

private:
    MGLMapViewMetalImpl& backend;

public:
    MGLMapViewImplDelegate* delegate = nil;
    MTKView *mtkView = nil;
//    EAGLContext *context = nil;
    const bool atLeastiOS_12_2_0;

    // We count how often the context was activated/deactivated so that we can truly deactivate it
    // after the activation count drops to 0.
    NSUInteger activationCount = 0;
};

MGLMapViewMetalImpl::MGLMapViewMetalImpl(MGLMapView* nativeView_)
    : MGLMapViewImpl(nativeView_),
      mbgl::gl::RendererBackend(mbgl::gfx::ContextMode::Unique),
      mbgl::gfx::Renderable({ 0, 0 }, std::make_unique<MGLMapViewMetalRenderableResource>(*this)) {
}

MGLMapViewMetalImpl::~MGLMapViewMetalImpl() {
//    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
//    if (resource.context && [[EAGLContext currentContext] isEqual:resource.context]) {
//        [EAGLContext setCurrentContext:nil];
//    }
}

void MGLMapViewMetalImpl::setOpaque(const bool opaque) {
    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
    resource.mtkView.opaque = opaque;
    resource.mtkView.layer.opaque = opaque;
}

void MGLMapViewMetalImpl::setPresentsWithTransaction(const bool value) {
//    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
    // ...
    
//    CAEAGLLayer* eaglLayer = MGL_OBJC_DYNAMIC_CAST(resource.glView.layer, CAEAGLLayer);
//    eaglLayer.presentsWithTransaction = value;
}

void MGLMapViewMetalImpl::display() {
    auto& resource = getResource<MGLMapViewMetalRenderableResource>();

    // Calling `display` here directly causes the stuttering bug (if
    // `presentsWithTransaction` is `YES` - see above)
    // as reported in https://github.com/mapbox/mapbox-gl-native-ios/issues/350
    //
    // Since we use `presentsWithTransaction` to synchronize with UIView
    // annotations, we now let the system handle when the view is rendered. This
    // has the potential to increase latency
    [resource.mtkView setNeedsDisplay];
}

void MGLMapViewMetalImpl::createView() {
    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
    if (resource.mtkView) {
        return;
    }

//    if (!resource.context) {
//        resource.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
//        assert(resource.context);
//    }

//    resource.glView = [[GLKView alloc] initWithFrame:mapView.bounds context:resource.context];
//    resource.glView =
    resource.mtkView.delegate = resource.delegate;
    resource.mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    resource.mtkView.contentScaleFactor = contentScaleFactor();
    resource.mtkView.contentMode = UIViewContentModeCenter;
//    resource.glView.drawableStencilFormat = GLKViewDrawableStencilFormat8;
//    resource.glView.drawableDepthFormat = GLKViewDrawableDepthFormat16;
    resource.mtkView.opaque = mapView.opaque;
    resource.mtkView.layer.opaque = mapView.opaque;
    resource.mtkView.enableSetNeedsDisplay = YES;
//    CAEAGLLayer* eaglLayer = MGL_OBJC_DYNAMIC_CAST(resource.glView.layer, CAEAGLLayer);
//    eaglLayer.presentsWithTransaction = NO;

    [mapView insertSubview:resource.mtkView atIndex:0];
}

UIView* MGLMapViewMetalImpl::getView() {
    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
    return resource.mtkView;
}

void MGLMapViewMetalImpl::deleteView() {
//    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
//    [resource.mtkView deleteDrawable];
}

#ifdef MGL_RECREATE_GL_IN_AN_EMERGENCY
// TODO: Fix or remove
// See https://github.com/mapbox/mapbox-gl-native/issues/14232
void MGLMapViewMetalImpl::emergencyRecreateGL() {
    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
    MGLLogError(@"Rendering took too long - creating GL views");

//    CAEAGLLayer* eaglLayer = MGL_OBJC_DYNAMIC_CAST(resource.glView.layer, CAEAGLLayer);
//    eaglLayer.presentsWithTransaction = NO;

    [mapView pauseRendering:nil];

    // Just performing a pauseRendering:/resumeRendering: pair isn't sufficient - in this case
    // we can still get errors when calling bindDrawable. Here we completely
    // recreate the GLKView

    [mapView.userLocationAnnotationView removeFromSuperview];
    [resource.glView removeFromSuperview];

    // Recreate the view
    resource.glView = nil;
    createView();

    if (mapView.annotationContainerView) {
        [resource.glView insertSubview:mapView.annotationContainerView atIndex:0];
    }

    [mapView updateUserLocationAnnotationView];

    // Do not bind...yet

    if (mapView.window) {
        [mapView resumeRendering:nil];
//        eaglLayer = MGL_OBJC_DYNAMIC_CAST(resource.glView.layer, CAEAGLLayer);
//        eaglLayer.presentsWithTransaction = mapView.enablePresentsWithTransaction;
    } else {
        MGLLogDebug(@"No window - skipping resumeRendering");
    }
}
#endif

mbgl::gl::ProcAddress MGLMapViewMetalImpl::getExtensionFunctionPointer(const char* name) {
    static CFBundleRef framework = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.metal"));
    if (!framework) {
        throw std::runtime_error("Failed to load Metal framework.");
    }

    return reinterpret_cast<mbgl::gl::ProcAddress>(CFBundleGetFunctionPointerForName(
        framework, (__bridge CFStringRef)[NSString stringWithUTF8String:name]));
}

void MGLMapViewMetalImpl::activate() {
    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
    if (resource.activationCount++) {
        return;
    }

//    [EAGLContext setCurrentContext:resource.context];
}

void MGLMapViewMetalImpl::deactivate() {
    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
    if (--resource.activationCount) {
        return;
    }

//    [EAGLContext setCurrentContext:nil];
}

/// This function is called before we start rendering, when iOS invokes our rendering method.
/// iOS already sets the correct framebuffer and viewport for us, so we need to update the
/// context state with the anticipated values.
void MGLMapViewMetalImpl::updateAssumedState() {
//    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
//    assumeFramebufferBinding(ImplicitFramebufferBinding);
//    assumeViewport(0, 0, resource.framebufferSize());
}

void MGLMapViewMetalImpl::restoreFramebufferBinding() {
//    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
//    if (!implicitFramebufferBound()) {
        // Something modified our state, and we need to bind the original drawable again.
        // Doing this also sets the viewport to the full framebuffer.
        // Note that in reality, iOS does not use the Framebuffer 0 (it's typically 1), and we
        // only use this is a placeholder value.
//        [resource.mtkView bindDrawable];
//        updateAssumedState();
//    } else {
        // Our framebuffer is still bound, but the viewport might have changed.
//        setViewport(0, 0, resource.framebufferSize());
//    }
}

//UIImage* MGLMapViewMetalImpl::snapshot() {
//    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
//
////    return resource.mtkView.snapshot;
//}

void MGLMapViewMetalImpl::layoutChanged() {
    const auto scaleFactor = contentScaleFactor();
    size = { static_cast<uint32_t>(mapView.bounds.size.width * scaleFactor),
             static_cast<uint32_t>(mapView.bounds.size.height * scaleFactor) };
}

//EAGLContext* MGLMapViewMetalImpl::getEAGLContext() {
//    auto& resource = getResource<MGLMapViewMetalRenderableResource>();
//    return resource.context;
//}
