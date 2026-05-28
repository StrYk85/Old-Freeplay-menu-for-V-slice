import flixel.group.FlxTypedSpriteGroup;
import funkin.ui.AtlasText;
import funkin.ui.AtlasChar;
import funkin.play.components.HealthIcon;
import funkin.ui.freeplay.FreeplaySongData;
import funkin.data.character.CharacterDataParser;

class FreeplayMenuItem extends FlxTypedSpriteGroup {

    public var txt:AtlasText;
    public var icon:HealthIcon;
    public var text:String;

    public var selected(default, set):Bool = false;
    function set_selected(val):Bool {
        selected = val;
        txt.alpha = icon.alpha = selected? 1 : 0.6;
        return val;
    }

    public var freeplayData:Null<FreeplaySongData> = null;

    public function new() {
        super();
        txt = new AtlasText(0, 0, '', 'bold');
        add(txt);
        icon = new HealthIcon();
        add(icon);
    }

    public function initInfo(daText:String, iconData) {
        icon.configure(iconData);
        icon.iconOffset.set(); // doing this because otherwise the icon doesn't show up for spaghetti
        icon.updateHitbox();

        var nums = [for (i in 0...11) Std.string(i)];
        txt.text = daText;

        for (letter in txt) {
            if (nums.contains(letter.char)) {
                letter.kill();
                letter.frames = Paths.getSparrowAtlas('fonts/boldNumbers');
                letter.char += '0';
                letter.y = 0 + txt.maxHeight - letter.height;
                letter.revive();
            }
        }

        // wow just like psych engine
        var wordCount = 20;
        var averageWidth = 40 * wordCount + icon.width;

        if (txt.width > averageWidth) {
            var daWidth = averageWidth / txt.width;
            for (letter in txt) {
                letter.scale.x *= daWidth;
                letter.updateHitbox();
                letter.x *= daWidth;
            }
        }
        icon.setPosition(txt.x + txt.width + 15, txt.y + (txt.height - icon.height) / 2 + 10);
    }

    public function initData(dataToUse:Null<FreeplaySongData>) {
        this.freeplayData = dataToUse;
        final charData = CharacterDataParser.fetchCharacterData(freeplayData.songCharacter);

        var iconData = charData?.healthIcon;
        var actualText = freeplayData.fullSongName;
        initInfo(actualText, iconData);
    }
}