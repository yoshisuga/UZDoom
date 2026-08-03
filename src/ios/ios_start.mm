//
//  ios_start.m
//  zdoom_native
//
//  Created by Yoshi Sugawara on 11/14/21.
//

#import <Foundation/Foundation.h>

#include "basics.h"	// for min(); st_start.h no longer pulls this in transitively
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

// NOTE: The FStartupScreen net API (NetInit/NetConnect/NetDisconnect/ShouldStartNet/
// GetNetKickClient/GetNetBanClient/NetLoop/NetProgress/NetMessage/NetUpdate/NetDone/
// NetClose) was removed upstream when the netgame lobby moved to ZWidget. The iOS
// implementations that used to live here — including the IOS_ShowSystemModal /
// IOS_SpinRunLoop / Bonjour hooks — no longer have a base-class call site and were
// dropped. iOS multiplayer needs to be rebuilt against the new lobby.


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
