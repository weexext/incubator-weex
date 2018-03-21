/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import "WXBaseViewController.h"
#import "WXRootViewController.h"
#import "WXSDKInstance.h"
#import "WXSDKInstance_private.h"
#import "WXSDKEngine.h"
#import "WXSDKManager.h"
#import "WXUtility.h"
#import "WXPrerenderManager.h"
#import "WXMonitor.h"

//===========================
#import "WXConvert.h"
//===========================

@interface WXBaseViewController ()

@property (nonatomic, strong) WXSDKInstance *instance;
@property (nonatomic, strong) UIView *weexView;
@property (nonatomic, strong) NSURL *sourceURL;

//==============================================
//@property (nonatomic, strong) UIColor *titleColor;
@property (nonatomic, strong) UIView *naviView;
@property (nonatomic, strong) NSDictionary *ucx_param;
//==============================================

@end

@implementation WXBaseViewController

- (void)dealloc
{
    [_instance destroyInstance];
    [self _removeObservers];
}

- (instancetype)initWithSourceURL:(NSURL *)sourceURL
{
    if ((self = [super init])) {
        self.sourceURL = sourceURL;
        self.hidesBottomBarWhenPushed = YES;
        
        [self _addObservers];
    }
    return self;
}

/**
 *  After setting the navbar hidden status , this function will be called automatically. In this function, we
 *  set the height of mainView equal to screen height, because there is something wrong with the layout of
 *  page content.
 */

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if ([self.navigationController isKindOfClass:[WXRootViewController class]]) {
        CGRect frame = self.view.frame;
        frame.origin.y = 0;
        frame.size.height = [UIScreen mainScreen].bounds.size.height;
        self.view.frame = frame;
    }    
}

/**
 *  We assume that the initial state of viewController's navigtionBar is hidden.  By setting the attribute of
 *  'dataRole' equal to 'navbar', the navigationBar hidden will be NO.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self _renderWithURL:_sourceURL];
//============================
    [self addNaviView];
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = YES;
//============================
    if ([self.navigationController isKindOfClass:[WXRootViewController class]]) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    }

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self _updateInstanceState:WeexInstanceAppear];
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self _updateInstanceState:WeexInstanceDisappear];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    [self _updateInstanceState:WeexInstanceMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshWeex
{
    [self _renderWithURL:_sourceURL];
}


- (void)addEdgePop
{
    self.navigationController.interactivePopGestureRecognizer.delegate = self;
}

- (void)_renderWithURL:(NSURL *)sourceURL
{
    if (!sourceURL) {
        return;
    }
    
    [_instance destroyInstance];
    if([WXPrerenderManager isTaskReady:[self.sourceURL absoluteString]]){
        _instance = [WXPrerenderManager instanceFromUrl:self.sourceURL.absoluteString];
    }

    _instance = [[WXSDKInstance alloc] init];
    _instance.frame = CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, self.view.bounds.size.height);
    _instance.pageObject = self;
    _instance.pageName = sourceURL.absoluteString;
    _instance.viewController = self;
    
    NSString *newURL = nil;
    
    if ([sourceURL.absoluteString rangeOfString:@"?"].location != NSNotFound) {
        newURL = [NSString stringWithFormat:@"%@&random=%d", sourceURL.absoluteString, arc4random()];
    } else {
        newURL = [NSString stringWithFormat:@"%@?random=%d", sourceURL.absoluteString, arc4random()];
    }
    [_instance renderWithURL:[NSURL URLWithString:newURL] options:@{@"bundleUrl":sourceURL.absoluteString} data:nil];
    
    __weak typeof(self) weakSelf = self;
    _instance.onCreate = ^(UIView *view) {
        [weakSelf.weexView removeFromSuperview];
        weakSelf.weexView = view;
        [weakSelf.view addSubview:weakSelf.weexView];
    };
    
    _instance.onFailed = ^(NSError *error) {
        
    };
    
    _instance.renderFinish = ^(UIView *view) {
        [weakSelf _updateInstanceState:WeexInstanceAppear];
    };
    
    if([WXPrerenderManager isTaskReady:[self.sourceURL absoluteString]]){
        WX_MONITOR_INSTANCE_PERF_START(WXPTJSDownload, _instance);
        WX_MONITOR_INSTANCE_PERF_END(WXPTJSDownload, _instance);
        WX_MONITOR_INSTANCE_PERF_START(WXPTFirstScreenRender, _instance);
        WX_MONITOR_INSTANCE_PERF_START(WXPTAllRender, _instance);
        [WXPrerenderManager renderFromCache:[self.sourceURL absoluteString]];
        return;
    }
}

- (void)_updateInstanceState:(WXState)state
{
    if (_instance && _instance.state != state) {
        _instance.state = state;
        
        if (state == WeexInstanceAppear) {
            [[WXSDKManager bridgeMgr] fireEvent:_instance.instanceId ref:WX_SDK_ROOT_REF type:@"viewappear" params:nil domChanges:nil];
        } else if (state == WeexInstanceDisappear) {
            [[WXSDKManager bridgeMgr] fireEvent:_instance.instanceId ref:WX_SDK_ROOT_REF type:@"viewdisappear" params:nil domChanges:nil];
        }
    }
}

- (void)_appStateDidChange:(NSNotification *)notify
{
    if ([notify.name isEqualToString:@"UIApplicationDidBecomeActiveNotification"]) {
        [self _updateInstanceState:WeexInstanceForeground];
    } else if([notify.name isEqualToString:@"UIApplicationDidEnterBackgroundNotification"]) {
        [self _updateInstanceState:WeexInstanceBackground]; ;
    }
}

- (void)_addObservers
{
    for (NSString *name in @[UIApplicationDidBecomeActiveNotification,
                             UIApplicationDidEnterBackgroundNotification]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_appStateDidChange:)
                                                     name:name
                                                   object:nil];
    }
}

- (void)_removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


//===================================

- (instancetype)initWithSourceURL:(NSURL *)sourceURL ext:(NSDictionary *)dict {
    self = [self initWithSourceURL:sourceURL];
    if (self) {
        self.ucx_param = [dict copy];
    }
    
    return self;
}

#pragma mark -
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (event.subtype == UIEventSubtypeMotionShake) { // 判断是否是摇动结束
        WXLog(@"UIEventSubtypeMotionShake");
        [self refreshWeex];
    }
    return;
}

#pragma mark -
- (void)addNaviView {
//    if(!_titleColor)
//        _titleColor = [UIColor colorWithRed:56/255.f green:81/255.f blue:152/255.f alpha:1.f];
    NSString *ucx_navBarColor = @"#385198";
    NSString *ucx_backgroundColor = @"#f4f4f1";
    if ([self.ucx_param count]>0) {
        NSDictionary *ucx_navBar = [self.ucx_param objectForKey:@"navBar"];
        if ([ucx_navBar count]>0 && [ucx_navBar isKindOfClass:[NSDictionary class]]) {
            NSString *navBarColor = [ucx_navBar objectForKey:@"navBarColor"];
            if (navBarColor) {
                ucx_navBarColor = navBarColor;
            }
            NSString *backgroundColor = [ucx_navBar objectForKey:@"backgroundColor"];
            if (backgroundColor) {
                ucx_backgroundColor = backgroundColor;
            }
        }
    }
    
    [self.naviView removeFromSuperview];
    float width = [UIScreen mainScreen].bounds.size.width;
    self.naviView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 128*width/750)];
    [self.naviView setBackgroundColor:[WXConvert UIColor:ucx_navBarColor]];
    
    [self.view addSubview:self.naviView];
    self.view.backgroundColor = [WXConvert UIColor:ucx_backgroundColor];
}
//===================================
@end
