import funkin.modding.module.Module;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.transition.stickers.StickerSubState;
import funkin.play.PlayState;
import funkin.play.ResultState;
import flixel.util.FlxTimer;

class FreeplayLogic extends Module {
    
    public function new() {
        super('FreeplayLogic', 0);
    }

    // I don't know what I am doing.
    // Trying to redirect states in V-Slice SUCKS.

    public static var lastDifficulty:String = 'hard';
    public static var lastSongId:Null<String> = null;
    public static var lastVariation:String = 'bf';
    public static var lastCharacter:String = 'bf';

    public function onSubStateOpenBegin(e:SubStateScriptEvent) {
        if (Std.isOfType(e.targetState, FreeplayState)) {
            if (Std.isOfType(FlxG.state, MainMenuState)) {
                e.cancel();
                FlxG.state.startExitState(() -> new OLDfreeplay());
            }
        }
    }

    var didIt:Bool = false;

    public function onSubStateOpenEnd(e:SubStateScriptEvent) {
        if (Std.isOfType(e.targetState, FreeplayState)) 
            FlxG.switchState(new OLDfreeplay());

        if (Std.isOfType(e.targetState, StickerSubState) 
            && (Std.isOfType(FlxG.state, PlayState) || (Std.isOfType(FlxG.state, ResultState) && !FlxG.state.params.storyMode)) 
            && !didIt) {
            FlxTimer.globalManager.clear();
            e.targetState.targetState = (stickers) -> {new OLDfreeplay(stickers);};
            e.targetState.regenStickers();
            didIt = true;
        }
        else didIt = false;
    }
}