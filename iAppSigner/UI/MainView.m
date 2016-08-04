//
//  MainView.m
//  iAppSigner
//
//  Created by Alan Marcan on 26.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "MainView.h"
#import "FileTypeHelper.h"
#import "FileCopyHelper.h"
#import "ProvProfileParserOperation.h"
#import "CertificatesLoaderOperation.h"
#import "ProcessAndSignOperation.h"


@interface MainView() <NSOpenSavePanelDelegate>
{
	__block NSString *_provProfilePath;
	__block NSDictionary *_provProfileDict;
	__block NSString *_ipaFilePath;
	__block NSArray<NSString *> *_avaiableCertificates;
	__block NSString *_selectedCertificateName;
	__block BOOL _signingInProgress;
}

@property (weak) IBOutlet NSTextField *certLabelTextField;
@property (weak) IBOutlet NSPopUpButton *certPopUpButton;
@property (weak) IBOutlet NSTextField *provProfileLabelTextField;
@property (weak) IBOutlet NSTextField *provProfileTextField;
@property (weak) IBOutlet NSButton *browseProvProfileButton;
@property (weak) IBOutlet NSButton *browseIPAFileButton;
@property (weak) IBOutlet NSTextField *ipaFileTextField;
@property (weak) IBOutlet NSButton *signButton;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *updateEntCheckButton;
@property (weak) IBOutlet NSTextField *updateEntLabelTextField;
@property (weak) IBOutlet NSButton *updateEntHelpButton;
@property (weak) IBOutlet NSTextField *logLabelTextField;
@property (weak) IBOutlet NSScrollView *logScrollView;
@property (assign) IBOutlet NSTextView *logTextView;

@end


@implementation MainView

static NSString *defaultLogFontName = @"Menlo";
static CGFloat defaultLogFontSize = 11.;


#pragma mark - init / dealloc

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];

	if (self)
	{
		[self registerForDraggedTypes:@[NSFilenamesPboardType]];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(logAdded:)
													 name:kLogAddedNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(logCleared:)
													 name:kLogClearedNotification
												   object:nil];

		NSFontManager *fontManager = [NSFontManager sharedFontManager];
		fontManager.target = self;
		NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
		[colorPanel setTarget:self];
		[colorPanel setAction:@selector(changeColor:)];
	}

	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - NSNibAwaking

- (void)awakeFromNib
{
	_certLabelTextField.stringValue = LSTR(@"MainView.Certificate");
	_provProfileLabelTextField.stringValue = LSTR(@"MainView.ProvProfile");
	_provProfileTextField.placeholderString = LSTR(@"MainView.ProvProfilePlaceholder");
	_browseProvProfileButton.title = LSTR(@"Common.Browse");
	_browseIPAFileButton.title = LSTR(@"MainView.IPAFile");
	_ipaFileTextField.placeholderString = LSTR(@"MainView.IPAFilePlaceholder");
	_signButton.title = LSTR(@"MainView.Sign");
	_updateEntLabelTextField.stringValue = LSTR(@"MainView.EntUpdate");
	_updateEntLabelTextField.toolTip = [NSString stringWithFormat:LSTR(@"MainView.EntUpdateHelpFrmt"), _updateEntLabelTextField.stringValue];
	_updateEntCheckButton.toolTip = _updateEntLabelTextField.toolTip;
	[[NSHelpManager sharedHelpManager] setContextHelp:[[NSAttributedString alloc] initWithString:_updateEntLabelTextField.toolTip]
											forObject:_updateEntHelpButton];
	_logLabelTextField.stringValue = LSTR(@"MainView.Log");

	_logTextView.font = [NSFont fontWithName:defaultLogFontName size:defaultLogFontSize];
}


#pragma mark - Panel Actions

- (void)changeFont:(NSFontManager *)fontManager
{
	_logTextView.font = [fontManager convertFont:_logTextView.font];
}


- (void)changeAttributes:(NSFontManager *)fontManager
{
}


- (void)changeColor:(NSColorPanel *)colorPanel
{
	_logTextView.textColor = colorPanel.color;
}


#pragma mark - IB Actions

- (IBAction)showUpdateEntHelpHelp:(NSButton *)button
{
	[[NSHelpManager sharedHelpManager] showContextHelpForObject:button locationHint:[NSEvent mouseLocation]];
}


- (IBAction)browseClicked:(NSButton *)button
{
	button.enabled = NO;
	WSELF;

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.delegate = self;
	panel.canChooseDirectories = NO;
	panel.allowsMultipleSelection = NO;
	[panel beginSheetModalForWindow:APPDEL.window
				  completionHandler:^(NSInteger result)
	{
		if (result == NSFileHandlingPanelOKButton)
		{
			NSURL *fileUrl = [panel.URLs firstObject];

			if (button == _browseProvProfileButton)
			{
				[wself loadProvProfileAtPath:fileUrl.path];
			}
			else if (button == _browseIPAFileButton)
			{
				[wself loadIPAFileAtPath:fileUrl.path withName:fileUrl.lastPathComponent];
			}
		}

		button.enabled = YES;
		[wself checkEnableSign];
	}];
}


- (IBAction)signClicked:(NSButton *)button
{
	_signingInProgress = YES;
	_certPopUpButton.enabled = NO;
	_browseProvProfileButton.enabled = NO;
	_browseIPAFileButton.enabled = NO;
	_signButton.enabled = NO;
	[_progressIndicator startAnimation:self];

	ProcessAndSignOperation *signOp = [ProcessAndSignOperation operationWithCertificate:_selectedCertificateName
																		provProfilePath:_provProfilePath
																		provProfileDict:_provProfileDict
																			ipaFilePath:_ipaFilePath
																	 updateEntitlements:(_updateEntCheckButton.state == NSOnState)
																		 andFinishBlock:^(BOOL success, NSString *tmpIPAFilePath)
	{
		[_progressIndicator stopAnimation:self];
		_certPopUpButton.enabled = YES;
		_browseProvProfileButton.enabled = YES;
		_browseIPAFileButton.enabled = YES;
		_signButton.enabled = YES;
		_signingInProgress = NO;

		BOOL saveNeeded = (tmpIPAFilePath.length > 0);

		NSAlert *alert = [NSAlert new];

		if (!success)
		{
			alert.alertStyle = NSInformationalAlertStyle;
			alert.messageText = LSTR(@"MainView.Alert.SignErrorMessage");
			alert.informativeText = [NSString stringWithFormat:LSTR(@"MainView.Alert.SignErrorInfo")];
		}
		else
		{
			alert.messageText = LSTR(@"MainView.Alert.SignSuccessMessage");

			if (saveNeeded)
			{
				alert.alertStyle = NSInformationalAlertStyle;
				alert.informativeText = [NSString stringWithFormat:LSTR(@"MainView.Alert.SignSuccessInfo")];
			}
		}

		[alert addButtonWithTitle:LSTR(@"Common.OK")];
		[alert runModal];


		if (success && saveNeeded)
		{
			NSOpenPanel *panel = [NSOpenPanel openPanel];
			panel.delegate = self;
			panel.canChooseDirectories = YES;
			panel.canChooseFiles = NO;
			panel.allowsMultipleSelection = NO;
			[panel beginSheetModalForWindow:APPDEL.window
						  completionHandler:^(NSInteger result)
			{
				NSError *error = nil;

				if (result == NSFileHandlingPanelOKButton)
				{
					NSURL *fileUrl = [panel.URLs firstObject];
					[FileCopyHelper atomicFileCopyAtPath:tmpIPAFilePath
												  toPath:[fileUrl.path stringByAppendingPathComponent:_ipaFilePath.lastPathComponent]
												   error:&error];

					if (!!error)
					{
						DLog(@"%@", error);
					}
				}

				error = nil;
				[[NSFileManager defaultManager] removeItemAtPath:tmpIPAFilePath error:&error];

				if (!!error)
				{
					DLog(@"%@", error);
				}


			}];
		}
	}];

	[APPDEL.mainQueue addOperation:signOp];
}


- (IBAction)certChanged:(NSPopUpButton *)popUpButton
{
	NSInteger index = popUpButton.indexOfSelectedItem;

	if (index >= 0)
	{
		_selectedCertificateName = _avaiableCertificates[index];
	}
}


- (IBAction)clearLogClicked:(NSButton *)button
{
	[LogHelper clearLog];
}


#pragma mark - Notifications

- (void)logAdded:(NSNotification *)notification
{
	_logTextView.string = [_logTextView.string stringByAppendingString:notification.userInfo[kLogNotificationUserInfokey]];

	NSPoint origin = _logScrollView.contentView.documentRect.origin;
	origin.y = _logScrollView.contentView.documentRect.size.height;
	[_logScrollView.contentView setBoundsOrigin:origin];
}


- (void)logCleared:(NSNotification *)notification
{
	_logTextView.string = kEmptyString;
}


#pragma mark - NSDraggingDestination

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	if (!_signingInProgress)
	{
		[self dragActionWithSender:sender
			   forProvProfileBlock:^(NSString *path)
		{
			_provProfileTextField.alphaValue = .3;
			_browseProvProfileButton.enabled = NO;
			[NSApp activateIgnoringOtherApps:YES];
		}
				   andIPAFileBlock:^(NSString *path)
		{
			_ipaFileTextField.alphaValue = .3;
			_browseIPAFileButton.enabled = NO;
			[NSApp activateIgnoringOtherApps:YES];
		}];
	}

	return NSDragOperationGeneric;
}


- (void)draggingExited:(id<NSDraggingInfo>)sender
{
	if (!_signingInProgress)
	{
		[self dragActionWithSender:sender
			   forProvProfileBlock:^(NSString *path)
		{
			_provProfileTextField.alphaValue = 1.;
			_browseProvProfileButton.enabled = YES;
		}
				   andIPAFileBlock:^(NSString *path)
		{
			_ipaFileTextField.alphaValue = 1.;
			_browseIPAFileButton.enabled = YES;
		}];
	}
}


- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	__block BOOL perform = NO;

	if (!_signingInProgress)
	{
		[self dragActionWithSender:sender
			   forProvProfileBlock:^(NSString *path)
		{
			perform = YES;
		}
				   andIPAFileBlock:^(NSString *path)
		{
			perform = YES;
		}];
	}

	return perform;
}


- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
	if (!_signingInProgress)
	{
		WSELF;

		[self dragActionWithSender:sender
			   forProvProfileBlock:^(NSString *path)
		{
			[wself loadProvProfileAtPath:path];
			_provProfileTextField.alphaValue = 1.;
			_browseProvProfileButton.enabled = YES;
		}
				   andIPAFileBlock:^(NSString *path)
		{
			[wself loadIPAFileAtPath:path withName:path.lastPathComponent];
			_ipaFileTextField.alphaValue = 1.;
			_browseIPAFileButton.enabled = YES;
		}];
	}
}


#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url
{
	return (_signingInProgress
			? YES
			: ((!_browseProvProfileButton.isEnabled && [FileTypeHelper isExtensionProvProfile:url.pathExtension])
			   || (!_browseIPAFileButton.isEnabled && [FileTypeHelper isExtensionIPAFile:url.pathExtension])));
}


#pragma mark - Private methods

- (void)dragActionWithSender:(id<NSDraggingInfo>)sender
		 forProvProfileBlock:(void (^)(NSString *path))provProfileActionBlock
			 andIPAFileBlock:(void (^)(NSString *path))ipaActionBlock

{
	NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	NSString *path = [draggedFilenames objectAtIndex:0];
	NSString *extension = [path pathExtension];

	if ([FileTypeHelper isExtensionProvProfile:extension] && provProfileActionBlock)
	{
		provProfileActionBlock(path);
	}
	else if ([FileTypeHelper isExtensionIPAFile:extension] && ipaActionBlock)
	{
		ipaActionBlock(path);
	}
}


- (void)loadProvProfileAtPath:(NSString *)path
{
	WSELF;
	_provProfilePath = path;

	ProvProfileParserOperation *parseOp = [ProvProfileParserOperation operationWithProvProfilePath:_provProfilePath
																					andFinishBlock:^(NSDictionary *provProfileDict)
	{
		if (provProfileDict.count > 0)
		{
			CertificatesLoaderOperation *signOp = [CertificatesLoaderOperation operationWithProvProfileDict:provProfileDict
																							 andFinishBlock:^(NSArray<NSString *> *avaiableCertificates)
			{
				if (avaiableCertificates.count > 0)
				{
					_provProfileDict = provProfileDict;
					_provProfileTextField.stringValue = _provProfileDict[kProvProfileNameKey];
					_avaiableCertificates = avaiableCertificates;
					_selectedCertificateName = avaiableCertificates[0];
					[_certPopUpButton removeAllItems];
					[_certPopUpButton addItemsWithTitles:_avaiableCertificates];
					[_certPopUpButton selectItemAtIndex:0];
					[_certPopUpButton synchronizeTitleAndSelectedItem];
					_certPopUpButton.enabled = YES;
					[wself checkEnableSign];
				}
				else
				{
					[wself invalidateProvProfile];
				}
			}];

			[APPDEL.mainQueue addOperation:signOp];
		}
		else
		{
			[wself invalidateProvProfile];
		}
	}];

	[APPDEL.mainQueue addOperation:parseOp];
}


- (void)invalidateProvProfile
{
	_certPopUpButton.enabled = NO;
	[_certPopUpButton selectItemAtIndex:-1];
	[_certPopUpButton removeAllItems];
	[_certPopUpButton synchronizeTitleAndSelectedItem];
	_provProfileTextField.stringValue = kEmptyString;
	_provProfileDict = nil;
	_provProfilePath = nil;
	_avaiableCertificates = nil;
	_selectedCertificateName = nil;
	[self checkEnableSign];

	NSAlert *alert = [NSAlert new];
	alert.alertStyle = NSInformationalAlertStyle;
	alert.messageText = LSTR(@"MainView.Alert.ProvProfileErrorMessage");
	alert.informativeText = [NSString stringWithFormat:LSTR(@"MainView.Alert.ProvProfileErrorInfo")];
	[alert addButtonWithTitle:LSTR(@"Common.OK")];
	[alert runModal];
}


- (void)loadIPAFileAtPath:(NSString *)path withName:(NSString *)ipaName
{
	_ipaFilePath = path;
	_ipaFileTextField.stringValue = ipaName;
	[self checkEnableSign];
}


- (void)checkEnableSign
{
	_signButton.enabled = (_selectedCertificateName.length > 0 && _provProfileDict.count > 0 && _ipaFilePath.length > 0);
}

@end
