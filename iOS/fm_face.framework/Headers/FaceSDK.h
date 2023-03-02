#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

enum SDK_INIT_RESULT
{
    SDK_SUCCESS = 0,
    SDK_ACTIVATE_INVALID_LICENSE,
    SDK_ACTIVATE_APPID_ERROR,
    SDK_ACTIVATE_LICENSE_EXPIRED,
    SDK_NO_ACTIVATED,
    SDK_INIT_ERROR,
};

@interface FaceBox : NSObject

@property (nonatomic) int left;
@property (nonatomic) int top;
@property (nonatomic) int right;
@property (nonatomic) int bottom;
@end

@interface FaceSDK : NSObject

+(FaceSDK*) createInstance;
+(FaceSDK*) getInstance;

-(int) initSDK: (NSString*) license;
-(NSMutableArray*) detectFace: (UIImage*) image;
-(float) checkLiveness: (UIImage*) image faceBox: (FaceBox*) faceBox;
-(NSData*) extractFeature: (UIImage*) image faceBox: (FaceBox*) faceBox;
-(float) compareFeature: (NSData*) feature1 feature2: (NSData*) feature2;

@end

NS_ASSUME_NONNULL_END
