//
//  ios_start.m
//  zdoom_native
//
//  Created by Yoshi Sugawara on 11/14/21.
//

#import <Foundation/Foundation.h>

#include "c_cvars.h"
#include "st_start.h"
#include "printf.h"
#include "engineerrors.h"

// FStartupScreen *StartScreen;

FBasicStartupScreen::FBasicStartupScreen(int maxProgress)
: FStartupScreen(maxProgress)
{
    NSLog(@"FBasicStartupScreen: set maxprogress: %i", maxProgress);
}

FBasicStartupScreen::~FBasicStartupScreen()
{
    NSLog(@"FBasicStartupScreen deinit?");
}

void FBasicStartupScreen::Progress(int advance)
{
	CurPos = min(CurPos + advance, MaxPos);
	NSLog(@"FBasicStartupScreen::Progress set progress (%i / %i)",CurPos,MaxPos);
}

void FBasicStartupScreen::NetInit(const char* const message, const bool host)
{
    NSLog(@"FBasicStartupScreen::NetInit: %s playercount=%i", message, host);
}

void FBasicStartupScreen::NetConnect(const int client, const char* const name, const unsigned flags, const int status) {
	NSLog(@"FBasicStartupScreen::NetConnect client=%i, name=%s, flags=%u, status=%i", client, name, flags, status);
}

void FBasicStartupScreen::NetDisconnect(const int client) {
	
}

bool FBasicStartupScreen::ShouldStartNet() {
	return false;
}

int FBasicStartupScreen::GetNetKickClient()
{
	return 0;
}

int FBasicStartupScreen::GetNetBanClient()
{
	return 0;
}

bool FBasicStartupScreen::NetLoop(bool (*loopCallback)(void*), void* const data)
{
	while (true)
	{
		if (loopCallback(data))
		{
			break;
		}

		[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];

		// Do not poll to often
		usleep(50000);
	}

	return true;
}

void FBasicStartupScreen::NetProgress(const int cur, const int limit)
{
    NSLog(@"FBasicStartupScreen::NetProgress cur= %i, limit=%i",cur,limit);
}

void FBasicStartupScreen::NetMessage(const char* const message)
{
	NSLog(@"FBasicStartupScreen::NetMessage:%s", message);
}

void FBasicStartupScreen::NetUpdate(const int client, const int status)
{
	
}

void FBasicStartupScreen::NetDone()
{
    NSLog(@"FBasicStartupScreen::NetDone");
}

void FBasicStartupScreen::NetClose()
{
//   FConsoleWindow::GetInstance().NetClose();
  NSLog(@"FBasicStartupScreen::NetClose");
}


// ---------------------------------------------------------------------------


//FStartupScreen *FStartupScreen::CreateInstance(const int maxProgress, bool showprogress)
//{
//    return new FBasicStartupScreen(maxProgress, showprogress);
//}


// ---------------------------------------------------------------------------


//void ST_Endoom()
//{
//    throw CExitEvent(0);
//}
