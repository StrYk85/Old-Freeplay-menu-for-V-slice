import flixel.FlxSprite;
import funkin.Paths;
import funkin.Assets;

class FreeplayBG extends FlxSprite {
    
    public var currentBG:String = '';

    function setBG(curChar:String) {
        var oldBG = currentBG;
        currentBG = Assets.exists(Paths.image('menuBGBlue-$curChar'))? 'menuBGBlue-$curChar' : 'menuBGBlue';

        if (oldBG != currentBG) loadGraphic(Paths.image(currentBG));
    }

    public function new(?char:String) {
        super();
        setBG(char);
        setGraphicSize(Std.int(FlxG.width));
        updateHitbox();
        screenCenter();
    }
}