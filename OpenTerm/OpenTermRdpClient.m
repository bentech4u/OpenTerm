#define __COREFOUNDATION_CFPLUGINCOM__ 1

#import "OpenTermRdpClient.h"

#import <freerdp/client.h>
#import <freerdp/settings.h>
#import <freerdp/settings_keys.h>
#import <freerdp/settings_types.h>

#import <Cocoa/Cocoa.h>

#import "MRDPView.h"
#import "mf_client.h"
#import "mfreerdp.h"

@interface OpenTermRdpClient ()
@property (nonatomic, strong) OpenTermRdpConfig *config;
@property (nonatomic, strong) MRDPView *internalView;
@end

@implementation OpenTermRdpConfig
@end

@implementation OpenTermRdpClient {
    rdpContext *_context;
    BOOL _isConnected;
}

- (instancetype)initWithConfig:(OpenTermRdpConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
        _internalView = [[MRDPView alloc] initWithFrame:NSMakeRect(0, 0, 1024, 768)];
    }
    return self;
}

- (NSView *)view {
    return self.internalView;
}

- (BOOL)isConnected {
    return _isConnected;
}

- (void)connect {
    if (_isConnected) {
        return;
    }

    [self setupContextIfNeeded];
    [self applySettings];

    // Use MRDPView's rdpStart method which properly initializes the view and starts the client thread
    int status = [self.internalView rdpStart:_context];
    _isConnected = (status == 0);
}

- (void)disconnect {
    if (!_context) {
        return;
    }

    freerdp_client_stop(_context);
    freerdp_client_context_free(_context);
    _context = NULL;
    _isConnected = NO;
}

- (void)updateViewportWidth:(NSInteger)width height:(NSInteger)height {
    if (width <= 0 || height <= 0) {
        return;
    }

    // Only update scroll offsets once the RDP view is connected and initialized.
    if (!_isConnected) {
        return;
    }

    [self.internalView setScrollOffset:0 y:0 w:(int)width h:(int)height];
}

- (void)dealloc {
    [self disconnect];
}

- (void)setupContextIfNeeded {
    if (_context) {
        return;
    }

    RDP_CLIENT_ENTRY_POINTS clientEntryPoints;
    memset(&clientEntryPoints, 0, sizeof(clientEntryPoints));
    clientEntryPoints.Size = sizeof(clientEntryPoints);
    clientEntryPoints.Version = RDP_CLIENT_INTERFACE_VERSION;

    RdpClientEntry(&clientEntryPoints);

    _context = freerdp_client_context_new(&clientEntryPoints);
    if (!_context) {
        return;
    }

    mfContext *mfc = (mfContext *)_context;
    mfc->view = (__bridge void *)self.internalView;
    mfc->view_ownership = FALSE;
}

- (void)applySettings {
    if (!_context) {
        return;
    }

    rdpSettings *settings = _context->settings;

    freerdp_settings_set_string(settings, FreeRDP_ServerHostname, self.config.hostname.UTF8String);
    freerdp_settings_set_uint32(settings, FreeRDP_ServerPort, self.config.port);
    freerdp_settings_set_string(settings, FreeRDP_Username, self.config.username.UTF8String);

    if (self.config.password.length > 0) {
        freerdp_settings_set_string(settings, FreeRDP_Password, self.config.password.UTF8String);
    }

    freerdp_settings_set_bool(settings, FreeRDP_RedirectClipboard, self.config.clipboardEnabled ? TRUE : FALSE);
    if (self.config.clipboardEnabled) {
        freerdp_settings_set_uint32(settings, FreeRDP_ClipboardFeatureMask, CLIPRDR_FLAG_DEFAULT_MASK);
    }

    BOOL audioPlayback = (self.config.soundMode != OpenTermRdpSoundModeOff);
    freerdp_settings_set_bool(settings, FreeRDP_AudioPlayback, audioPlayback ? TRUE : FALSE);
    freerdp_settings_set_bool(settings, FreeRDP_RemoteConsoleAudio,
                              (self.config.soundMode == OpenTermRdpSoundModeRemote) ? TRUE : FALSE);

    BOOL fullscreen = (self.config.displayMode == OpenTermRdpDisplayModeFullscreen);
    BOOL smartSizing = (self.config.displayMode == OpenTermRdpDisplayModeFitToWindow);
    freerdp_settings_set_bool(settings, FreeRDP_Fullscreen, fullscreen ? TRUE : FALSE);
    freerdp_settings_set_bool(settings, FreeRDP_SmartSizing, smartSizing ? TRUE : FALSE);
    freerdp_settings_set_bool(settings, FreeRDP_DynamicResolutionUpdate, smartSizing ? TRUE : FALSE);

    UINT32 width = (UINT32)MAX(self.config.width, 320);
    UINT32 height = (UINT32)MAX(self.config.height, 240);

    if (fullscreen) {
        NSScreen *screen = [NSScreen mainScreen];
        if (screen != nil) {
            NSRect frame = [screen frame];
            width = (UINT32)frame.size.width;
            height = (UINT32)frame.size.height;
        }
    }

    freerdp_settings_set_uint32(settings, FreeRDP_DesktopWidth, width);
    freerdp_settings_set_uint32(settings, FreeRDP_DesktopHeight, height);

    [self applyPerformanceProfile:settings];
}

- (void)applyPerformanceProfile:(rdpSettings *)settings {
    switch (self.config.performanceProfile) {
        case OpenTermRdpPerformanceProfileBestQuality:
            freerdp_settings_set_uint32(settings, FreeRDP_ColorDepth, 32);
            freerdp_settings_set_bool(settings, FreeRDP_DisableWallpaper, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableFullWindowDrag, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableMenuAnims, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableThemes, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableCursorShadow, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableCursorBlinking, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_AllowFontSmoothing, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_AllowDesktopComposition, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_BitmapCacheEnabled, TRUE);
            // Graphics Pipeline for modern RDP
            freerdp_settings_set_bool(settings, FreeRDP_SupportGraphicsPipeline, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_GfxH264, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_GfxAVC444, TRUE);
            break;

        case OpenTermRdpPerformanceProfileBalanced:
            freerdp_settings_set_uint32(settings, FreeRDP_ColorDepth, 24);
            freerdp_settings_set_bool(settings, FreeRDP_DisableWallpaper, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableFullWindowDrag, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableMenuAnims, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableThemes, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableCursorShadow, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableCursorBlinking, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_AllowFontSmoothing, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_AllowDesktopComposition, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_BitmapCacheEnabled, TRUE);
            // Graphics Pipeline with H.264
            freerdp_settings_set_bool(settings, FreeRDP_SupportGraphicsPipeline, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_GfxH264, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_GfxAVC444, FALSE);
            break;

        case OpenTermRdpPerformanceProfileBestPerformance:
            freerdp_settings_set_uint32(settings, FreeRDP_ColorDepth, 16);
            freerdp_settings_set_bool(settings, FreeRDP_DisableWallpaper, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableFullWindowDrag, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableMenuAnims, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableThemes, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableCursorShadow, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_DisableCursorBlinking, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_AllowFontSmoothing, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_AllowDesktopComposition, FALSE);
            freerdp_settings_set_bool(settings, FreeRDP_BitmapCacheEnabled, TRUE);
            freerdp_settings_set_bool(settings, FreeRDP_BitmapCacheV3Enabled, TRUE);
            // Disable Graphics Pipeline for maximum compatibility/performance on low bandwidth
            freerdp_settings_set_bool(settings, FreeRDP_SupportGraphicsPipeline, FALSE);
            break;
    }
}

@end
