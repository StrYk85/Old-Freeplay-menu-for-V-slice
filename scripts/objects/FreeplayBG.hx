import flixel.FlxSprite;
import funkin.save.Save;

class FreeplayBG extends FlxSprite {
    
    public var currentBG:String = '';

    function setBG(curChar:String) {
        var oldBG = currentBG;
        if (Save.instance.modOptions["CharacterBackgrounds"] && Assets.exists(Paths.image('menuBGBlue-$curChar'))) currentBG = 'menuBGBlue-$curChar';
        else currentBG = 'menuBGBlue';

        if (oldBG != currentBG) {
            loadGraphic(Paths.image(currentBG));
            setGraphicSize(Std.int(FlxG.width));
            updateHitbox();
            screenCenter();
        }
    }

    public function new(?char:String) {
        super();
        setBG(char);
    }
}