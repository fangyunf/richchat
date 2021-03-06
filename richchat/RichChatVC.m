//
//  RichChatVC.m
//  richchatdemo
//
//  Created by jia wang on 3/7/13.
//  Copyright (c) 2013 Colin. All rights reserved.
//

#import "RichChatVC.h"
#import "MoodFaceVC.h"


//富聊天条目的模型实现
@implementation RichChatItem
@synthesize itemType;
@synthesize itemSenderTitle;
@synthesize itemContent;
@synthesize itemSenderFace;
@synthesize itemTime;
@synthesize itemSenderIsSelf;
@end

//富聊天视图控制的私有成员变量
@interface RichChatVC ()<MoodFaceDelegate>{
    CGFloat _heightKeyboard;
    UITableView * _table;
    UIImageView * _ivBg;
    UITextField * _tfBg;
    HPGrowingTextView * _tvInput;
    UIButton * _btnVoice;
    UIButton * _btnFace;
    UIButton * _btnPlus;
    UIButton * _btnTalk;
    UIButton * _btnCancel;
    UIButton * _btnTitleCancel;
    //    UIButton * _btnCellVoice;
    UIImageView * _ivPlayingWave;
    
    BOOL  _isPan;
    BOOL  _isShowMood;
}
@property(nonatomic,strong)MoodFaceVC * mood;
@property(nonatomic,strong)NHPlayer * media;
@end

//富聊天视图控制的实现
@implementation RichChatVC
@synthesize delegate=_delegate;
@synthesize mood=_mood;
@synthesize media=_media;


//#define INPUT_SINGLE_LINE_HEIGHT 40 //64
//#define INPUT_FONT_SIZE        20
//#define INPUT_SINGLE_LINE_HEIGHT 43 //70
//#define INPUT_FONT_SIZE        22
//#define INPUT_SINGLE_LINE_HEIGHT 45 //74
//#define INPUT_FONT_SIZE        24

-(void)dealloc{
    _refreshHeaderView = nil;
    _media.delegate=nil;
    [_media release];
    [_mood release];
    [super dealloc];
}
-(void)loadView{
    UIView * view=[[UIView alloc]init];
    CGRect  bounds=[[UIScreen mainScreen]applicationFrame];
    view.frame=CGRectMake(0, 0, bounds.size.width, self.navigationController.navigationBarHidden?bounds.size.height:(bounds.size.height/*-self.navigationController.navigationBar.frame.size.height*/));
    self.view=view;
    bounds=self.view.frame;
    [view release];
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //聊天记录
    UITableView * table=[[UITableView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 0) style:UITableViewStylePlain];
    table.dataSource=self;
    table.delegate=self;
    if (DEBUG_MODE) {
        table.separatorStyle=UITableViewCellSeparatorStyleSingleLine;
        table.backgroundColor=[UIColor cyanColor];
    }else{
        table.separatorStyle=UITableViewCellSeparatorStyleNone;
        table.backgroundColor=[UIColor clearColor];
    }
    
    
    [self.view addSubview:table];
    _table = table;
    [table release];
    
    if (_refreshHeaderView == nil) {
		
		EGORefreshTableHeaderView *view = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - _table.bounds.size.height, self.view.frame.size.width, _table.bounds.size.height)];
		view.delegate = self;
		[_table addSubview:view];
		_refreshHeaderView = view;
		[view release];
		
	}
    
    UIBarButtonItem * btnRefresh=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(requestForNearest20messages)];
    self.navigationItem.rightBarButtonItem=btnRefresh;
    [btnRefresh release];
    
    //输入区域
    UIImageView * ivBg=[[UIImageView alloc]initWithImage:nil];
    ivBg.userInteractionEnabled=YES;
    ivBg.backgroundColor=[UIColor lightGrayColor];
    ivBg.frame=CGRectMake(0, 0, self.view.frame.size.width, INPUT_SINGLE_LINE_HEIGHT+10);
    _ivBg=ivBg;
    [self.view addSubview:ivBg];
    [ivBg release];
    
    //+按钮
    UIImage * imgPlus=[UIImage imageNamed:@"plus"];
    UIButton * btnPlus=[UIButton buttonWithType:UIButtonTypeCustom];
    btnPlus.frame=CGRectMake(0, _tvInput.frame.origin.y, imgPlus.size.width, imgPlus.size.height);
    [btnPlus setBackgroundImage:imgPlus forState:UIControlStateNormal];
    //    [btnPlus addTarget:self action:@selector(onClickSend:) forControlEvents:UIControlEventTouchUpInside];
    _btnPlus = btnPlus;
    [ivBg addSubview:btnPlus];
    
    //表情按钮
    UIImage * imgFace=[UIImage imageNamed:@"happy"];
    UIImage * imgText=[UIImage imageNamed:@"text"];
    UIButton * btnFace=[UIButton buttonWithType:UIButtonTypeCustom];
    btnFace.frame=CGRectMake(INPUT_SINGLE_LINE_HEIGHT, _tvInput.frame.origin.y, imgFace.size.width,imgFace.size.height);
    [btnFace setBackgroundImage:imgFace forState:UIControlStateNormal];
    [btnFace setBackgroundImage:imgText forState:UIControlStateSelected];
    [btnFace addTarget:self action:@selector(onClickFace:) forControlEvents:UIControlEventTouchUpInside];
    _btnFace = btnFace;
    [ivBg addSubview:btnFace];
    
    //文字框背景
    UITextField * tf=[[UITextField alloc]init];
    tf.frame=CGRectMake(INPUT_SINGLE_LINE_HEIGHT*2, 5, ivBg.frame.size.width-INPUT_SINGLE_LINE_HEIGHT*3, INPUT_SINGLE_LINE_HEIGHT);
    [tf setBorderStyle:UITextBorderStyleRoundedRect];
    tf.userInteractionEnabled=NO;
    [ivBg addSubview:tf];
    _tfBg=tf;
    //    _tfBg.hidden=YES;
    [tf release];
    
    //文字框
    HPGrowingTextView * tv=[[HPGrowingTextView alloc]init];
    tv.font=[UIFont systemFontOfSize:INPUT_FONT_SIZE];
    tv.delegate=self;
    tv.internalTextView.backgroundColor=[UIColor clearColor];
    tv.frame=tf.frame;
    //    tv.keyboardType=UIKeyboardTypeDefault;
    tv.returnKeyType=UIReturnKeySend;
    tv.contentMode=UIControlContentVerticalAlignmentBottom;
    [ivBg addSubview:tv];
    _tvInput=tv;
    [tv release];
    
    //voice/text按钮
    UIImage * imgVoice=[UIImage imageNamed:@"voice"];
    UIImage * imgTextBlue=[UIImage imageNamed:@"txt_blue"];
    UIButton * btnVoice=[UIButton buttonWithType:UIButtonTypeCustom];
    btnVoice.frame=CGRectMake(ivBg.frame.size.width-INPUT_SINGLE_LINE_HEIGHT, _tvInput.frame.origin.y, imgVoice.size.width,imgVoice.size.height);
    [btnVoice setBackgroundImage:imgVoice forState:UIControlStateNormal];
    [btnVoice setBackgroundImage:imgTextBlue forState:UIControlStateSelected];
    [btnVoice addTarget:self action:@selector(onClickBtnVoiceText:) forControlEvents:UIControlEventTouchUpInside];
    _btnVoice = btnVoice;
    [ivBg addSubview:btnVoice];
    
    //Hold to talk
    UIButton * btnTalk=[UIButton buttonWithType:UIButtonTypeCustom];
    UIImage * img = [UIImage imageNamed:@"talk_blue"];
    btnTalk.frame=CGRectMake(btnPlus.frame.origin.x+btnPlus.frame.size.width
                             , ivBg.frame.size.height/2-img.size.height/2
                             ,btnVoice.frame.origin.x-btnPlus.frame.size.width-btnPlus.frame.origin.x
                             , img.size.height);
    [btnTalk setImage:img forState:UIControlStateNormal];
    if (DEBUG_MODE) {
        btnTalk.backgroundColor=[UIColor yellowColor];
    }
    [btnTalk setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
    //    [btnTalk setTitle:NSLocalizedString(@"Hold To Talk", nil) forState:UIControlStateNormal];
    _btnTalk=btnTalk;
    btnTalk.hidden=YES;
    [ivBg addSubview:btnTalk];
    [btnTalk addTarget:self action:@selector(onTalkTouchDown:) forControlEvents:UIControlEventTouchDown];
    [btnTalk addTarget:self action:@selector(onTalkTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    
    //move up to cancel
    UIButton * btnCancelImg=[UIButton buttonWithType:UIButtonTypeCustom];
    btnCancelImg.frame=CGRectMake(0, 0, 100, 120);
    btnCancelImg.center=CGPointMake(self.view.center.x, self.view.center.y-50);
    btnCancelImg.backgroundColor=[UIColor colorWithWhite:0 alpha:0.5];
    [btnCancelImg setImage:[UIImage imageNamed:@"mic_black"] forState:UIControlStateNormal];
    [btnCancelImg setImage:[UIImage imageNamed:@"trash_black"] forState:UIControlStateSelected];
    [btnCancelImg setImageEdgeInsets:UIEdgeInsetsMake(-20.0f,0, 0, 0)];
    [self.view addSubview:btnCancelImg];
    _btnCancel=btnCancelImg;
    _btnCancel.hidden=YES;
    
    CGFloat hTitle=30.0f;
    UIButton * btnCancelLabel=[UIButton buttonWithType:UIButtonTypeCustom];
    btnCancelLabel.titleLabel.font=[UIFont systemFontOfSize:10];
    btnCancelLabel.frame=CGRectMake(0, btnCancelImg.frame.size.height-hTitle, btnCancelImg.frame.size.width, hTitle);
    [btnCancelLabel setTitle:@"手指上滑取消发送" forState:UIControlStateNormal];
    [btnCancelLabel setTitle:@"松开手指取消发送" forState:UIControlStateSelected];
    [btnCancelLabel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_btnCancel addSubview:btnCancelLabel];
    _btnTitleCancel=btnCancelLabel;


    
    
    //手势
    UIPanGestureRecognizer * pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(handlePanGesture:)];
    [_btnTalk addGestureRecognizer:pan];
    [pan release];
    
    //监听键盘高度的变换
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // 键盘高度变化通知，ios5.0新增的
#ifdef __IPHONE_5_0
    float version = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (version >= 5.0) {
        //        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:nil];
    }
#endif
    
    
    
    MoodFaceVC * mvc=[[MoodFaceVC alloc]init];
    mvc.delegate=self;
    mvc.mNWith=self.view.frame.size.width-VIEW_INSET*2-FACE_HEIGHT-CONTENT_INSET_BIG-CONTENT_INSET_SMALL;
    mvc.mNWordSize=CONTENT_FONT_SIZE;
    mvc.mNImgSize=24;
    self.mood=mvc;
    CGRect rcMood = _mood.view.frame;
    rcMood.origin.y=_ivBg.frame.size.height+_ivBg.frame.origin.y;
    _mood.view.frame=rcMood;
    [self.view addSubview:mvc.view];
    [mvc release];
    
    NHPlayer * player=[[NHPlayer alloc]init];
    player.delegate=self;
    self.media=player;
    [player release];
    
    [self requestForNearest20messages];
}
-(void)viewWillAppear:(BOOL)animated{
    [self autoMovekeyBoard:0 duration:0];
}
#pragma mark Responding to keyboard events
- (void)keyboardWillShow:(NSNotification *)notification {
    
    /*
     Reduce the size of the text view so that it's not obscured by the keyboard.
     Animate the resize so that it's in sync with the appearance of the keyboard.
     */
    _btnFace.selected=NO;
    NSDictionary *userInfo = [notification userInfo];
    
    // Get the origin of the keyboard when it's displayed.
    NSValue* aValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    
    // Get the top of the keyboard as the y coordinate of its origin in self's view's coordinate system. The bottom of the text view's frame should align with the top of the keyboard's final position.
    CGRect keyboardRect = [aValue CGRectValue];
    
    // Get the duration of the animation.
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    
    // Animate the resize of the text view's frame in sync with the keyboard's appearance.
    _heightKeyboard=keyboardRect.size.height;
    [self autoMovekeyBoard:keyboardRect.size.height duration:animationDuration];
}


- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary* userInfo = [notification userInfo];
    
    /*
     Restore the size of the text view (fill self's view).
     Animate the resize so that it's in sync with the disappearance of the keyboard.
     */
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    
    if (_btnFace.selected) {
        //把键盘撤掉就行了，就不把编辑区域整体下移了
    }else{
        [self autoMovekeyBoard:0 duration:animationDuration];
    }
    
}

-(void) autoMovekeyBoard: (float) h duration:(NSTimeInterval)time{
    
    [UIView animateWithDuration:time animations:^{
        _ivBg.frame= CGRectMake(_ivBg.frame.origin.x
                                , (float)(self.view.frame.size.height-h-INPUT_SINGLE_LINE_HEIGHT-10)
                                , _ivBg.frame.size.width
                                , INPUT_SINGLE_LINE_HEIGHT+10);
        
        _tfBg.frame=CGRectMake(_tfBg.frame.origin.x, _tfBg.frame.origin.y, _tfBg.frame.size.width, INPUT_SINGLE_LINE_HEIGHT);
        _tvInput.frame=_tfBg.frame;
        
        CGRect rc=_btnVoice.frame;
        rc.origin.y=_ivBg.frame.size.height-5-rc.size.height;
        _btnVoice.frame=rc;
        
        rc.size.width=INPUT_SINGLE_LINE_HEIGHT;
        rc.origin.x=0;
        _btnPlus.frame=rc;
        
        rc.origin.x=INPUT_SINGLE_LINE_HEIGHT;
        _btnFace.frame=rc;
        
        //通知栏20，导航栏44，编辑框INPUT_SINGLE_LINE_HEIGHT
        _table.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width,(float)(self.view.frame.size.height-h-INPUT_SINGLE_LINE_HEIGHT-10));
        CGRect rcMood = _mood.view.frame;
        rcMood.origin.y=_ivBg.frame.size.height+_ivBg.frame.origin.y;
        _mood.view.frame=rcMood;
        
        
        
    } completion:^(BOOL finished){
        if (finished) {
            [self moveTableViewToBottom];
        }
    }];
    
    
    
    
}

#pragma mark - funtions


-(void)onTalkTouchDown:(UIButton *)sender{
    _isPan=NO;
    _btnCancel.hidden=NO;
    
    NSString * strPath=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"talk" stringByAppendingPathExtension:@"caf"]];
    [_media recordTo:strPath];
    NSLog(@"开始录音");
}
-(void)onTalkTouchUpInside:(UIButton *)sender{
    if (_isPan) {
        return;
    }
    _btnCancel.hidden=YES;
    NSLog(@"停止录音");
    NSURL * url = _media.audioRecorder.url;
    NSTimeInterval length=_media.audioRecorder.currentTime;
    [_media.audioRecorder stop];
    if (length>1) {
        //send
        
        [self sendMessage:[NSData dataWithContentsOfURL:url] type:ENUM_HISTORY_TYPE_VOICE];
        
    }else{
        //不够长
    }
    
    //     [self sendMessage:@"一段语音"];
}
-(void)onClickBtnVoiceText:(UIButton *)sender{
    sender.selected=!sender.selected;
    if (sender.selected) {
        //进入语音模式
        //        [_tvInput setText:@""];
        [_tvInput resignFirstResponder];
        [self autoMovekeyBoard:0 duration:0.3];
    } else {
        //回到文字模式
        [_tvInput becomeFirstResponder];
    }
    _btnFace.hidden=sender.selected;
    _tfBg.hidden=sender.selected;
    _tvInput.hidden=sender.selected;
    _btnTalk.hidden=!sender.selected;
}
-(void)handlePanGesture:(UIPanGestureRecognizer *)pan{
    CGPoint point = [pan locationInView:self.view];
    BOOL isOnLab = CGRectContainsPoint(_btnCancel.frame, point);
    _btnCancel.selected=isOnLab;
    _btnTitleCancel.selected=_btnCancel.selected;
    _isPan=YES;
    NSLog(@"%d,%d",isOnLab,pan.state);
    if (UIGestureRecognizerStateEnded==pan.state) {
        _btnCancel.selected=NO;
        _btnTitleCancel.selected=NO;
        _btnCancel.hidden=YES;
        NSLog(@"停止录音");
        NSURL * url = _media.audioRecorder.url;
        NSTimeInterval length=_media.audioRecorder.currentTime;
        [_media.audioRecorder stop];
        if (length>1&&!isOnLab) {
            //send
            [self sendMessage:[NSData dataWithContentsOfURL:url] type:ENUM_HISTORY_TYPE_VOICE];
        }
    }
    
    
}
-(void)onClickFace:(UIButton *)sender{
    
    if (_tvInput.internalTextView.isFirstResponder) {
        _btnFace.selected=YES;
        [_tvInput resignFirstResponder];
    }else{
        if (_btnFace.selected) {
            //              [self autoMovekeyBoard:0 duration:0.3];
            [_tvInput.internalTextView becomeFirstResponder];
            _btnFace.selected=NO;
            
        } else {
            [self autoMovekeyBoard:216 duration:0.3];
            _btnFace.selected=YES;
        }
        
    }
    
    
    
}
-(void)onUserSend
{
    _btnFace.selected=NO;
    
	NSString *messageStr = _tvInput.text;
    if (messageStr == nil || [[messageStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]isEqualToString:@""])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"发送失败" message:@"发送的内容不能为空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
        [alert show];
        [alert release];
    }else
    {
        
        [self sendMessage:messageStr type:ENUM_HISTORY_TYPE_TEXT];
        
    }
	_tvInput.text = @"";
	[_tvInput resignFirstResponder];
    
    
}
-(void)onClickCellButton:(UITapGestureRecognizer *)sender{
    if (self.delegate&&[self.delegate respondsToSelector:@selector(richChatHistoryItem:AtIndex:)])
    {
        RichChatItem * item=[[RichChatItem alloc]init];
        [self.delegate richChatHistoryItem:item AtIndex:sender.view.tag];
        
        if (ENUM_HISTORY_TYPE_VOICE==item.itemType) {
            [_media.audioPlayer stop];
            [_ivPlayingWave stopAnimating];
            

            for (UIView * view in sender.view.subviews) {
                if ([view isKindOfClass:[UIImageView class]]) {
                    
//                    [_ivPlayingWave stopAnimating];
                    if (_ivPlayingWave==(UIImageView *)view) {
                        _ivPlayingWave=nil;
                        return;
                    } else {
                        _ivPlayingWave=(UIImageView *)view;
                    }
                    
                }
            }
            
            NSURL * url=[NSURL URLWithString:item.itemContent];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSString * strPath=[item.itemContent lastPathComponent];
                    NSString * strDoc=[self voiceFileDocumentPath];
                                        
                    if (strDoc) {
                        strPath=[strDoc stringByAppendingPathComponent:strPath];
                        
                        NSData * data=nil;

                        if (![[NSFileManager defaultManager]fileExistsAtPath:strPath])
                        {  //不存在文件，则缓存下来并保存。
                            [self bubbleAlphaChange:sender.view forPath:strPath];
                            data=[NSData dataWithContentsOfURL:url];
                            NSError * error=nil;
                            BOOL res=[data writeToFile:strPath options:NSDataWritingFileProtectionNone error:&error];
                            if (res) {
                                NSLog(@"成功下载一段语音");
                                [self resizeBubble:sender.view file:strPath isSelf:item.itemSenderIsSelf];
                            }
                            

                        }else{
                            //存在的话，直接播放
                            data=[NSData dataWithContentsOfFile:strPath];
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            //隐藏下载进度条
                            [_ivPlayingWave startAnimating];
                            [_media playFileData:data];
                            
                            
                        });
                    }
                    
                    
                    
                });
                
                
            }
            
        
        [item release];
    }
}

#pragma mark - table

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RichChatItem * item=[[RichChatItem alloc]init];
    if (self.delegate && [self.delegate respondsToSelector:@selector(richChatHistoryItem:AtIndex:)]) {
        [self.delegate richChatHistoryItem:item AtIndex:indexPath.row];
    }
    CGFloat cellHeight=0;
    cellHeight=FACE_HEIGHT;
    if (item.itemType==ENUM_HISTORY_TYPE_TIME) {
        cellHeight=CELL_TYPE_TIME_HEIGHT;
    }else{
        if (item.itemType==ENUM_HISTORY_TYPE_TEXT) {
            NSString * strContent=item.itemContent;
            CGSize size=[_mood assembleMessageAtIndex:strContent].frame.size;
            if ((size.height+CONTENT_INSET_TOP+CONTENT_INSET_BOTTOM)>cellHeight) {
                cellHeight=size.height+CONTENT_INSET_TOP+CONTENT_INSET_BOTTOM;
            }
        }
        cellHeight+=CELLS_SEPERATE;
        
        if (CONTENT_DATE_LABLE_IS_SHOW) {
            cellHeight+=CONTENT_DATE_LABLE_HEIGHT;
        }
    }
    
    [item release];
    return cellHeight;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString * cellIdentify=@"historyCell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellIdentify];
    if (!cell) {
        cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentify];
    }
    cell.selectionStyle=UITableViewCellSelectionStyleNone;
    for (UIView * view in cell.contentView.subviews) {
        [view removeFromSuperview];
    }
    RichChatItem * item=[[RichChatItem alloc]init];
    if (self.delegate && [self.delegate respondsToSelector:@selector(richChatHistoryItem:AtIndex:)]) {
        [self.delegate richChatHistoryItem:item AtIndex:indexPath.row];
    }
    //是一条信息
    if (item.itemType&&(item.itemType!=ENUM_HISTORY_TYPE_TIME)) {
        //只要是信息，就一定有头像
        UIImageView * ivFace=[[UIImageView alloc]init];
        if (item.itemSenderFace && [item.itemSenderFace isKindOfClass:[UIImage class]]) {
            ivFace.image=item.itemSenderFace;
        }
        CGRect rcFace=CGRectMake(item.itemSenderIsSelf?(_table.frame.size.width-VIEW_INSET-FACE_HEIGHT):VIEW_INSET, [self tableView:tableView heightForRowAtIndexPath:indexPath]-FACE_HEIGHT, FACE_HEIGHT, FACE_HEIGHT);
        if (CONTENT_DATE_LABLE_IS_SHOW) {
            rcFace.origin.y-=CONTENT_DATE_LABLE_HEIGHT;
        }
        ivFace.frame=rcFace;
        [cell.contentView addSubview:ivFace];
        [ivFace release];
        
        CGRect rcContentBg=CGRectZero;
        UIImage * imgContentBg=[[UIImage imageNamed:(item.itemSenderIsSelf?@"bubbleSelf":@"bubble")]stretchableImageWithLeftCapWidth:item.itemSenderIsSelf?CONTENT_INSET_SMALL:CONTENT_INSET_BIG topCapHeight:16];
        //44*31 image size
        UIImageView * ivContentBg=[[UIImageView alloc]init];
        ivContentBg.userInteractionEnabled=YES;
        ivContentBg.image=imgContentBg;
        ivContentBg.tag=indexPath.row;
        [cell.contentView addSubview:ivContentBg];
        [ivContentBg release];
        
        UITapGestureRecognizer * tap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(onClickCellButton:)];
        [ivContentBg addGestureRecognizer:tap];
        
        if (item.itemType==ENUM_HISTORY_TYPE_TEXT)
        {
            NSString * strContent=item.itemContent;
            UIView * viewContent=[_mood assembleMessageAtIndex:strContent];
            CGSize sizeContent=viewContent.frame.size;
            if (sizeContent.height<27/*单行文字的高度*/) {
                sizeContent.height=27;
            }
            
            rcContentBg=CGRectMake(item.itemSenderIsSelf
                                   ?ivFace.frame.origin.x-sizeContent.width-CONTENT_INSET_BIG-CONTENT_INSET_SMALL
                                   :ivFace.frame.origin.x
                                   +ivFace.frame.size.width
                                   , CELLS_SEPERATE
                                   , sizeContent.width+CONTENT_INSET_BIG+CONTENT_INSET_SMALL
                                   , sizeContent.height+CONTENT_INSET_TOP+CONTENT_INSET_BOTTOM);
            CGRect rcContent=viewContent.frame;
            rcContent.origin.x=item.itemSenderIsSelf?CONTENT_INSET_SMALL:CONTENT_INSET_BIG;
            rcContent.origin.y=CONTENT_INSET_TOP;
            viewContent.frame=rcContent;
            if (DEBUG_MODE) {
                viewContent.backgroundColor=[UIColor colorWithWhite:0 alpha:0.3];
            }
            
            [ivContentBg addSubview:viewContent];
        }
        if (item.itemType==ENUM_HISTORY_TYPE_VOICE) {
           
            UIImage * imgPlay=[UIImage imageNamed:item.itemSenderIsSelf?@"waveself":@"wave"];
                       UIImageView * ivVoiceWave=[[UIImageView alloc]init];
            CGRect rcWave=CGRectMake(0, 0, imgPlay.size.width, imgPlay.size.height);
            rcWave.origin.x=item.itemSenderIsSelf?CONTENT_INSET_SMALL:CONTENT_INSET_BIG;
            rcWave.origin.y=CONTENT_INSET_TOP+5;
            ivVoiceWave.frame=rcWave;
            ivVoiceWave.image=imgPlay;
            
             NSTimeInterval length=0;
            //detect whether audio file downloaded
            NSString * strPath=[item.itemContent lastPathComponent];
            strPath=[[self voiceFileDocumentPath]stringByAppendingPathComponent:strPath];
            if (![[NSFileManager defaultManager]fileExistsAtPath:strPath]) {
                [self downloadVoice:item.itemContent bubble:ivContentBg wave:ivVoiceWave isSelf:item.itemSenderIsSelf];
            }else{
                length=[self getLengthOfVoice:strPath];
            }
            CGSize sizeContent=CGSizeMake(length*3+imgPlay.size.width, imgPlay.size.height);
            if (sizeContent.height<27/*单行文字的高度*/) {
                sizeContent.height=27;
            }
            rcContentBg=CGRectMake(item.itemSenderIsSelf
                                   ?ivFace.frame.origin.x-sizeContent.width-CONTENT_INSET_BIG-CONTENT_INSET_SMALL
                                   :ivFace.frame.origin.x
                                   +ivFace.frame.size.width
                                   , CELLS_SEPERATE
                                   , sizeContent.width+CONTENT_INSET_BIG+CONTENT_INSET_SMALL
                                   , sizeContent.height+CONTENT_INSET_TOP+CONTENT_INSET_BOTTOM);
            
            

            //prepare for playing animation elements
            NSMutableArray * animationImages=[[NSMutableArray alloc]init];
            for (int i=1; i<4; i++) {
                NSString * str=[NSString stringWithFormat:@"wave%d",i];
                if (item.itemSenderIsSelf) {
                    str=[str stringByAppendingString:@"self"];
                }
                UIImage * img=[UIImage imageNamed:str];
                [animationImages addObject:img];
                
            }
            ivVoiceWave.animationImages=animationImages;
            ivVoiceWave.animationDuration=1;
            [animationImages release];
            if (DEBUG_MODE) {
                [ivVoiceWave setBackgroundColor:[UIColor yellowColor]];
            }

            [ivContentBg addSubview:ivVoiceWave];
            
        }
        
        
        
        if (rcContentBg.size.height<FACE_HEIGHT) {
            //单行的时候，可以确保气泡下沿与头像下沿齐平
            rcContentBg.origin.y=CELLS_SEPERATE+FACE_HEIGHT-rcContentBg.size.height;
        }
        ivContentBg.frame=rcContentBg;
        if (CONTENT_DATE_LABLE_IS_SHOW)
        {
            UILabel * lbDate=[[UILabel alloc]init];
            if (DEBUG_MODE) {
                lbDate.backgroundColor=[UIColor brownColor];
            } else {
                lbDate.backgroundColor=[UIColor clearColor];
            }
            lbDate.font=[UIFont systemFontOfSize:CONTENT_DATE_LABLE_FONT_SIZE];
            NSDate * date=(NSDate *)item.itemTime;
            lbDate.text=[self caculateTime:[date timeIntervalSince1970]];
            lbDate.textAlignment=item.itemSenderIsSelf?UITextAlignmentRight:UITextAlignmentLeft;
            CGSize size=[lbDate.text sizeWithFont:lbDate.font];
            CGRect rc=CGRectMake(item.itemSenderIsSelf?(ivFace.frame.origin.x-size.width):(rcContentBg.size.width<size.width?(rcContentBg.origin.x+rcContentBg.origin.x):(rcContentBg.origin.x+rcContentBg.size.width-size.width)),
                                 rcContentBg.origin.y+rcContentBg.size.height
                                 , size.width
                                 , CONTENT_DATE_LABLE_HEIGHT);
            lbDate.frame=rc;
            [cell.contentView addSubview:lbDate];
            [lbDate release];
            
        }
        
        
    }else{
        //不是信息，是时间标签
        if (item.itemType==ENUM_HISTORY_TYPE_TIME) {
            UILabel * lbDate=[[UILabel alloc]init];
            if (DEBUG_MODE) {
                lbDate.backgroundColor=[UIColor greenColor];
            } else {
                lbDate.backgroundColor=[UIColor clearColor];
            }
            CGRect rc=CGRectMake(0, 0, _table.frame.size.width, CELL_TYPE_TIME_HEIGHT);
            lbDate.frame=rc;
            NSDate * date=(NSDate *)item.itemContent;
            lbDate.text=[self caculateTime:[date timeIntervalSince1970]];
            lbDate.textAlignment=UITextAlignmentCenter;
            [cell.contentView addSubview:lbDate];
            [lbDate release];
        }
        
    }
    
    [item release];
    return cell;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (self.delegate && [self.delegate respondsToSelector:@selector(richChatHistoryCount)]) {
        return [self.delegate richChatHistoryCount];
    }else
        return 0;
}
-(void)moveTableViewToBottom{
    NSInteger rowsCount=[_table numberOfRowsInSection:0];
    if (rowsCount>0) {
        NSIndexPath * pi=[NSIndexPath indexPathForRow:rowsCount-1 inSection:0];
        [_table scrollToRowAtIndexPath:pi atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
    
}
-(void)moveTableViewToTop{
    NSInteger rowsCount=[_table numberOfRowsInSection:0];
    if (rowsCount>0) {
        NSIndexPath * pi=[NSIndexPath indexPathForRow:0 inSection:0];
        [_table scrollToRowAtIndexPath:pi atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
    
}
-(void)reloadTableViewToTop:(BOOL)isToTop{
    [_table reloadData];
    if (isToTop) {
        [self moveTableViewToTop];
    } else {
        [self moveTableViewToBottom];
    }
    
}
#pragma mark - hptext delegate
-(void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height{
    
    _tfBg.frame=CGRectMake(_tfBg.frame.origin.x, _tfBg.frame.origin.y, _tfBg.frame.size.width, height);
    _tvInput.frame=_tfBg.frame;
    
    CGRect rc=_ivBg.frame;
    rc.size.height=height+10;
    rc.origin.y=self.view.frame.size.height-_heightKeyboard-rc.size.height;
    _ivBg.frame=rc;
    
    rc=_btnPlus.frame;
    rc.origin.y=_ivBg.frame.size.height-5-rc.size.height;
    _btnPlus.frame=rc;
    
    rc=_btnFace.frame;
    rc.origin.y=_ivBg.frame.size.height-5-rc.size.height;
    _btnFace.frame=rc;
    
    rc=_btnVoice.frame;
    rc.origin.y=_ivBg.frame.size.height-5-rc.size.height;
    _btnVoice.frame=rc;
    
    _table.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width,_ivBg.frame.origin.y);
    
    CGRect rcMood = _mood.view.frame;
    rcMood.origin.y=_ivBg.frame.size.height+_ivBg.frame.origin.y;
    _mood.view.frame=rcMood;
    
    [self moveTableViewToBottom];
}
-(BOOL)growingTextViewShouldReturn:(HPGrowingTextView *)growingTextView{
    //return key
    [self onUserSend];
    return NO;
}
#pragma mark - mood face delegate
-(void)moodFaceVC:(MoodFaceVC *)vc selected:(NSString *)strDescription imageName:(NSString *)strImg{
    [_tvInput.internalTextView setText:[_tvInput.internalTextView.text stringByAppendingString:strDescription]];
}
-(void)moodFaceVC:(MoodFaceVC *)vc onClickSend:(UIButton *)sender{
    [self onUserSend];
    [self autoMovekeyBoard:0 duration:0.3];
}
#pragma mark - nhplayer delegate
-(void)NHPlayer:(NHPlayer *)player onProgress:(CGFloat)progress{
    if (1==progress) {
        [_ivPlayingWave stopAnimating];
        _ivPlayingWave=nil;
    }
}
#pragma mark - common
-(void)requestForNearest20messages{
    if (self.delegate&&[self.delegate respondsToSelector:@selector(richChatRequestToUpdateHistory)]) {
        [self.delegate richChatRequestToUpdateHistory];
    }
}
-(void)sendMessage:(id)content type:(ENUM_HISTORY_TYPE)type{
    if (self.delegate && [self.delegate respondsToSelector:@selector(richChatRequestToSendMessage:type:)]) {
        [self.delegate richChatRequestToSendMessage:content type:type];
    }
    
}
-(void)bubbleAlphaChange:(UIView *)aniView forPath:(NSString*)strPath{
    [UIView animateWithDuration:0.5 animations:^{
        CGFloat al=aniView.alpha;
        if (al!=0.3f) {
            aniView.alpha=0.3f;
        }else{
            aniView.alpha=0.7f;
        }
    }completion:^(BOOL isFinish){
        if(isFinish){
            if (![[NSFileManager defaultManager]fileExistsAtPath:strPath]) {
                [self bubbleAlphaChange:aniView forPath:strPath];
            }else{
                aniView.alpha=1.0f;
            }
            
        }
        
    }];
}

-(NSTimeInterval)getLengthOfVoice:(NSString *)strPath{
    NSTimeInterval length=0;
    NSData * data=[[NSData alloc]initWithContentsOfFile:strPath];
    if (data) {
        AVAudioPlayer * player=[[AVAudioPlayer alloc]initWithData:data error:nil];
        if (player) {
            length =  player.duration;
        }
        [player release];
    }
    [data release];
    return length;
}
-(void)resizeBubble:(UIView *)ivBubble file:(NSString*)strPath isSelf:(BOOL)isSelf{
    NSData * data=[[NSData alloc]initWithContentsOfFile:strPath];
    if (data) {
        AVAudioPlayer * player=[[AVAudioPlayer alloc]initWithData:data error:nil];
        if (player) {
            NSTimeInterval length=player.duration;
            CGRect rc=ivBubble.frame;
            rc.size.width+=(length*3);
            if (isSelf) {
                rc.origin.x-=(length*3);
            }
            
            [UIView animateWithDuration:0.35 animations:^{
                ivBubble.frame=rc;
            }];
        }
        [player release];
    }
    [data release];
   
}
-(NSString *)voiceFileDocumentPath{
    NSArray * search=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,DOMAIN, YES);
    NSString * strDoc=search.count>0?[search objectAtIndex:0]:nil;
    if (strDoc) {
        strDoc=[strDoc stringByAppendingString:@"/RichChat/voice"];
        if (![[NSFileManager defaultManager]fileExistsAtPath:strDoc]) {
           BOOL res= [[NSFileManager defaultManager]createDirectoryAtPath:strDoc withIntermediateDirectories:YES attributes:nil error:nil];
            if (res) {
                return strDoc;
            }
            
        }else{
            return strDoc;
        }
    }
    return nil;

}
-(void)downloadVoice:(NSString *)strUrl bubble:(UIImageView *)ivBubble wave:(UIImageView *)ivWave isSelf:(BOOL)isSelf{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage * imgPlay=ivWave.image;
        ivWave.image=nil;
        NSString * strPath=[strUrl lastPathComponent];
        strPath=[[self voiceFileDocumentPath]stringByAppendingPathComponent:strPath];
        [self bubbleAlphaChange:ivBubble forPath:strPath];
        
        NSURL * url=[NSURL URLWithString:strUrl];
        NSData * data=[NSData dataWithContentsOfURL:url];
        NSError * error=nil;
        BOOL res=[data writeToFile:strPath options:NSDataWritingFileProtectionNone error:&error];
        if (res) {
            NSLog(@"成功下载一段语音");
            dispatch_async(dispatch_get_main_queue(), ^{
                ivWave.image=imgPlay;
                [self resizeBubble:ivBubble file:strPath isSelf:isSelf];
            });
        }
        
    });

}
- (NSString *)caculateTime:(double)aDInterval
{
    NSString *aTimeString=@"";
    NSTimeInterval aLate = aDInterval;
    
    NSDate* aDateNow= [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval aIntervalNow=[aDateNow timeIntervalSince1970]*1;
    
    NSTimeInterval aDifferenceValue = aIntervalNow-aLate;
    
    if (aDifferenceValue / 3600 < 1) {
        aTimeString = [NSString stringWithFormat:@"%f", aDifferenceValue/60];
        aTimeString = [aTimeString substringToIndex:aTimeString.length-7];
        
        NSInteger aInt = [aTimeString intValue];
        aTimeString=[NSString stringWithFormat:NSLocalizedString(@"%d分钟前",@""), aInt];
        
    }
    if (aDifferenceValue / 3600 > 1 && aDifferenceValue / 86400 < 1) {
        aTimeString = [NSString stringWithFormat:@"%f", aDifferenceValue/3600];
        aTimeString = [aTimeString substringToIndex:aTimeString.length-7];
        aTimeString=[NSString stringWithFormat:NSLocalizedString(@"%@小时前",@""), aTimeString];
    }
    if (aDifferenceValue/86400>1&&aDifferenceValue/86400<3)
    {
        aTimeString = [NSString stringWithFormat:@"%f", aDifferenceValue/86400];
        aTimeString = [aTimeString substringToIndex:aTimeString.length-7];
        aTimeString=[NSString stringWithFormat:NSLocalizedString(@"%@天前",@""), aTimeString];
    }
    if (aDifferenceValue/86400>3) {
        NSDateFormatter *date=[[NSDateFormatter alloc] init];
        //[date setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        [date setDateFormat:@"MM-dd HH:mm:ss"];
        
        NSTimeInterval aLateInterval = aLate - aIntervalNow;
        
        NSDate *aDateFull = [NSDate dateWithTimeIntervalSinceNow:aLateInterval];
        aTimeString = [date stringFromDate:aDateFull];
        [date release];
    }
    
    return aTimeString;
}
#pragma mark -
#pragma mark Data Source Loading / Reloading Methods

- (void)reloadTableViewDataSource{
	
	//  should be calling your tableviews data source model to reload
	//  put here just for demo
	_reloading = YES;
    if (self.delegate&&[self.delegate respondsToSelector:@selector(richChatRequestToLoadMore)]) {
        [self.delegate richChatRequestToLoadMore];
    }
	
}

- (void)doneLoadingTableViewData{
    
	//  model should call this when its done loading
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(doneLoadingTableViewDataAsync) userInfo:nil repeats:NO];
	
}
- (void)doneLoadingTableViewDataAsync{
    
	//  model should call this when its done loading
	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_table];
    
	
}
#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
	
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
    
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
	
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
	
}

#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view{
	
	[self reloadTableViewDataSource];
	
	
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view{
	
	return _reloading; // should return if data source model is reloading
	
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view{
	
	return [NSDate date]; // should return date data source was last changed
	
}


@end
