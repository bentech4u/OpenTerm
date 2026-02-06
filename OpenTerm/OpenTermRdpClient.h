#import <Foundation/Foundation.h>

@class NSView;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OpenTermRdpDisplayMode) {
    OpenTermRdpDisplayModeFitToWindow = 0,
    OpenTermRdpDisplayModeFullscreen = 1,
    OpenTermRdpDisplayModeFixed = 2
};

typedef NS_ENUM(NSInteger, OpenTermRdpSoundMode) {
    OpenTermRdpSoundModeOff = 0,
    OpenTermRdpSoundModeLocal = 1,
    OpenTermRdpSoundModeRemote = 2
};

typedef NS_ENUM(NSInteger, OpenTermRdpPerformanceProfile) {
    OpenTermRdpPerformanceProfileBestQuality = 0,
    OpenTermRdpPerformanceProfileBalanced = 1,
    OpenTermRdpPerformanceProfileBestPerformance = 2
};

@interface OpenTermRdpConfig : NSObject
@property (nonatomic, copy) NSString *hostname;
@property (nonatomic) uint16_t port;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic) OpenTermRdpDisplayMode displayMode;
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@property (nonatomic) BOOL clipboardEnabled;
@property (nonatomic) OpenTermRdpSoundMode soundMode;
@property (nonatomic) BOOL driveRedirectionEnabled;
@property (nonatomic) OpenTermRdpPerformanceProfile performanceProfile;
@end

@interface OpenTermRdpClient : NSObject
- (instancetype)initWithConfig:(OpenTermRdpConfig *)config;
@property (nonatomic, readonly) NSView *view;
@property (nonatomic, readonly) BOOL isConnected;
- (void)connect;
- (void)disconnect;
- (void)updateViewportWidth:(NSInteger)width height:(NSInteger)height;
@end

NS_ASSUME_NONNULL_END
