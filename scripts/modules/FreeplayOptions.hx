import flixel.FlxG;
import funkin.modding.module.Module;
import funkin.ui.options.OptionsState;
import funkin.save.Save;

class FreeplayOptions extends Module {

    public function new() {
		super("FreeplayOptions", 0);
        if (Save.instance.modOptions["CharacterBackgrounds"] == null) Save.instance.modOptions["CharacterBackgrounds"] = true;
	}

    public function onStateChangeEnd(e) {
        super.onStateChangeEnd(e);
        if (!Std.isOfType(e.targetState, OptionsState)) return;

        var prefs = e.targetState.optionsCodex.pages.get("preferences");
        if (prefs == null) return;

        prefs.createPrefItemCheckbox("Character Depended BGs", "If checked, the freeplay background changes depending on the currently selected character (if available).", function(value:Bool) {
			Save.instance.modOptions["CharacterBackgrounds"] = value;
			Save.instance.flush();
		}, Save.instance.modOptions["CharacterBackgrounds"]);
	}
}