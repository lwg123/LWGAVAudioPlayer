//
//  ViewController.m
//  LWGAVAudioPlayer
//
//  Created by weiguang on 2017/2/9.
//  Copyright © 2017年 weiguang. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#define kMusicFile @"刘若英 - 原来你也在这里.mp3"
#define kMusicSinger @"刘若英"
#define kMusicTitle @"原来你也在这里"

@interface ViewController ()<AVAudioPlayerDelegate>

@property (nonatomic,strong) AVAudioPlayer *audioPlayer; //播放器

@property (weak, nonatomic) IBOutlet UILabel *singer;  //演唱者
@property (weak, nonatomic) IBOutlet UIButton *downloadBtn;
@property (weak, nonatomic) IBOutlet UIButton *loveBtn;
@property (weak, nonatomic) IBOutlet UIButton *playBtn; // 播放/暂停按钮(如果tag为0认为是暂停状态，1是播放状态)
@property (weak, nonatomic) IBOutlet UIButton *prevBtn;
@property (weak, nonatomic) IBOutlet UIButton *nextBtn;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (nonatomic,weak) NSTimer *timer; // 进度更新定时器

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];

}

/**
 *  显示当面视图控制器时注册远程事件
 *
 *  @param animated 是否以动画的形式显示
 */
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    // 开启远程控制
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

/**
 *  当前控制器视图不显示时取消远程控制
 *
 *  @param animated 是否以动画的形式消失
 */
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
}

// 初始化UI
- (void)setupUI{
    self.title = kMusicTitle;
    self.singer.text = kMusicSinger;
}

- (NSTimer *)timer{
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    }
    return _timer;
}

/**
 *  创建播放器
 *
 *  @return 音频播放器
 */
- (AVAudioPlayer *)audioPlayer{
    if (!_audioPlayer) {
        NSString *urlStr = [[NSBundle mainBundle] pathForResource:kMusicFile ofType:nil];
        //此方法在iOS 9中已被弃用，建议使用下面的方法
        //NSString *str = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSString *str = [urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
        NSURL *url = [NSURL URLWithString:str];
        
        NSError *error = nil;
        //初始化播放器，注意这里的Url参数只能是文件路径，不支持HTTP Url
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        //设置播放器属性
        _audioPlayer.numberOfLoops = 0; //设置循环为0
        _audioPlayer.delegate = self;
        [_audioPlayer prepareToPlay]; //加载音频文件到缓存
        if (error) {
            NSLog(@"初始化播放器过程发生错误,错误信息:%@",error.localizedDescription);
            return nil;
        }
        //设置后台播放模式
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
        [audioSession setActive:YES error:nil];
        //添加通知，拔出耳机后暂停播放
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChange:) name:AVAudioSessionRouteChangeNotification object:nil];
        
    }
    return _audioPlayer;
}

/**
 *  播放音频
 */
- (void)play{
    if (![self.audioPlayer isPlaying]) {
        [self.audioPlayer play];
        self.timer.fireDate = [NSDate distantPast]; //恢复定时器
    }
}

/**
 *  暂停播放
 */
- (void)pause{
    if ([self.audioPlayer isPlaying]) {
        [self.audioPlayer pause];
        self.timer.fireDate = [NSDate distantFuture]; //暂停定时器，注意不能调用invalidate方法，此方法会取消，之后无法恢复
    }
}

/**
 *  点击播放/暂停按钮
 *
 *  @param sender 播放/暂停按钮
 */
- (IBAction)playClick:(UIButton *)sender {
    if (sender.tag) {
        sender.tag = 0;
        [sender setImage:[UIImage imageNamed:@"playing_btn_play_n"] forState:UIControlStateNormal];
        [sender setImage:[UIImage imageNamed:@"playing_btn_play_h"] forState:UIControlStateHighlighted];
        [self pause];
    }else {
        sender.tag = 1;
        [sender setImage:[UIImage imageNamed:@"playing_btn_pause_n"] forState:UIControlStateNormal];
        [sender setImage:[UIImage imageNamed:@"playing_btn_pause_h"] forState:UIControlStateHighlighted];
        [self play];

    }
}

/**
 *  更新播放进度
 */
- (void)updateProgress{
    float progress = self.audioPlayer.currentTime / self.audioPlayer.duration;
    [self.progressView setProgress:progress];
}

/**
 *  一旦输出改变则执行此方法
 *
 *  @param notification 输出改变通知对象
 */
- (void)routeChange:(NSNotification *)notification{
    NSDictionary *dic = notification.userInfo;
    int changeReason = [dic[AVAudioSessionRouteChangeReasonKey] intValue];
    //等于AVAudioSessionRouteChangeReasonOldDeviceUnavailable表示旧输出不可用
    if (changeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *routeDescription = dic[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *portDescription = [routeDescription.outputs firstObject];
        //原设备为耳机则暂停
        if ([portDescription.portType isEqualToString:@"Headphones"]) {
            [self pause];
        }
    }
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
}

#pragma mark - 播放器代理方法
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    NSLog(@"音乐播放完成...");
    //根据实际情况播放完成可以将会话关闭，其他音频应用继续播放
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
}

@end
