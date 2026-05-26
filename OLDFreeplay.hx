import flixel.FlxG;
import flixel.text.FlxText;
import flixel.text.FlxBitmapFont;
import flixel.text.FlxBitmapText;
import funkin.ui.MusicBeatState;
import flixel.group.FlxTypedGroup;
import funkin.data.song.SongRegistry;
import funkin.data.story.level.LevelRegistry;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funkin.ui.freeplay.FreeplaySongData;
import funkin.data.freeplay.player.PlayerRegistry;
import funkin.save.Save;
import funkin.graphics.FunkinSprite;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.audio.FunkinSound;
import funkin.ui.transition.LoadingState;
import funkin.ui.transition.stickers.StickerSubState;
import funkin.play.PlayStatePlaylist;
import funkin.util.MathUtil;
import flixel.util.FlxStringUtil;
import funkin.play.scoring.Scoring;

#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end

import funkin.util.SwipeUtil;
import flixel.addons.transition.FlxTransitionableState;
import StringTools;

class OLDfreeplay extends MusicBeatState {

    var stickerState = null;

    function new(?stickers:StickerSubState) {
        super();
        this.stickerState = stickers;
    }

    var canInteract:Bool = true;

    var bg:FunkinSprite;
    var currentBG = 'menuBGBlue';
    
    var songGroup:FlxTypedGroup<OLDFreeplayMenuItem> = new FlxTypedGroup();
    var charArray:Array<String> = [];

    var scoreTxt:FlxText;
    var scoreBG:FunkinSprite;
    var difficultyTxt:FlxText;
    var variationTxt:FlxText;
    
    var curSel:Int = 0;
    var curCharSel:Int = 0;

    var curDifficulty:String = 'easy';
    
    var curVariation(never, set):String = 'bf';
    var curChar:String = 'bf';
    function set_curVariation(value:String):String {
        curVariation = value;
        curChar = value == 'default'? charArray[curCharSel] : curVariation;
        FreeplayState.rememberedCharacterId = curChar;
        return curVariation;
    }

    var intendedScore:Float = 0;
    var lerpScore:Float = 0;
    var intendedPrecent:Float = 0;
    var lerpPrecent:Float = 0;

    var currentRank:String;

    override function create() {
        super.create();

        #if FEATURE_DISCORD_RPC
        DiscordClient.setPresence({state: 'In the Menus', details: null});
        #end

        curDifficulty = FreeplayLogic.lastDifficulty;
        curVariation = FreeplayLogic.lastVariation;

        for (i in PlayerRegistry.instance.listEntryIds()) charArray.push(i);
        curCharSel = charArray.indexOf(FreeplayLogic.lastCharacter);

        curChar = charArray[curCharSel];
        FreeplayState.rememberedCharacterId = curChar;

        persistentUpdate = true;
        persistentDraw = true;

        if (stickerState != null) {
            openSubState(stickerState);
            stickerState.degenStickers();
        }

        initUI();
        initList();
    }

    function initUI() {
        if (Assets.exists(Paths.image('menuBGBlue-${charArray[curCharSel]}'))) currentBG = 'menuBGBlue-${charArray[curCharSel]}';
        bg = new FunkinSprite(0, 0, Paths.image(currentBG));
        bg.setGraphicSize(Std.int(FlxG.width));
        bg.updateHitbox();
        bg.screenCenter();
        add(bg);

        add(songGroup);

        scoreBG = new FunkinSprite().makeSolidColor(Std.int(FlxG.width * 0.35), 91, 0xFF000000);
        scoreBG.alpha = 0.6;
        add(scoreBG);

        scoreTxt = doTxt(FlxG.width * 0.7, 5, 32);
        add(scoreTxt);

        difficultyTxt = doTxt(0, scoreTxt.y + 36, 24);
        add(difficultyTxt);
        
        variationTxt = doTxt(0, difficultyTxt.y + 36, 18);
        add(variationTxt);
    }

    function changeBG() {
        var prevBG = currentBG;
        if (Assets.exists(Paths.image('menuBGBlue-${charArray[curCharSel]}'))) currentBG = 'menuBGBlue-${charArray[curCharSel]}';
        else currentBG = 'menuBGBlue';

        if (prevBG != currentBG) bg.loadGraphic(Paths.image(currentBG));
    }

    function initList() {
        var songList:Array<FreeplaySongData> = [null];
        
        for (title in songGroup) songGroup.remove(title, true);
        songGroup.clear();

        // programmatically adds the songs via LevelRegistry and SongRegistry
        for (levelId in LevelRegistry.instance.listSortedLevelIds()) {
            var level:Level = LevelRegistry.instance.fetchEntry(levelId);
            if (level == null) continue;

            for (songId in level.getSongs()) {
                var song:Song = SongRegistry.instance.fetchEntry(songId);
                if (song == null) continue;

                var vars = song.getVariationsByCharacterId(curChar);
                var daSong = new FreeplaySongData(songId, level, this);

                if (daSong.data.listDifficulties(null, vars, false, false).length > 0)
                    songList.push(daSong);
            }
        }

        for (song in songList) {
            var item = new OLDFreeplayMenuItem();
            if (song != null) {
                // this is so stupid, but i have to do this so that it can show the icon of the opponent for the custom difficulties
                FreeplayState.rememberedDifficulty = song.data.listDifficulties(null, ['default'], false, false)[0];
                item.initData(song);
            }
            else 
                item.txt.text = 'random';
            
            songGroup.add(item);
        }
        FreeplayState.rememberedDifficulty = 'hard';

        curSel = 0;
        for (a => i in songGroup.members) {
            if (i.freeplayData != null && i.freeplayData.data.id == FreeplayLogic.lastSongId) {
                curSel = a;
                break;
            }
        }
        changeSel(0);
        changeBG();
    }

    function changeDif(amount:Int) {
        var songData = songGroup.members[curSel].freeplayData;
        var songDifficulties:Array<String> = Constants.DEFAULT_DIFFICULTY_LIST_FULL;
        var curVars;

        if (songData != null) {
            curVars = songData?.data.getVariationsByCharacterId(curChar) ?? Constants.DEFAULT_VARIATION_LIST;
            songDifficulties = songData?.data.listDifficulties(null, curVars, false, false) ?? Constants.DEFAULT_DIFFICULTY_LIST;
        }

        difIndex = songDifficulties.indexOf(curDifficulty) + amount;
        curDifficulty = songDifficulties[FlxMath.wrap(difIndex, 0, songDifficulties.length - 1)];

        if (curVars != null) {
            for (variation in curVars) {
                if (songData?.data.hasDifficulty(curDifficulty, variation) ?? false) {
                    curVariation = variation;
                    break;
                }
            }

            var songScore = Save.instance.getSongScore(songData?.data.id, curDifficulty, curVariation);
            intendedScore = songScore?.score ?? 0;
            intendedPrecent = songScore?.tallies != null? Math.max(0, Scoring.tallyCompletion(songScore?.tallies)) : null;

            currentRank = Scoring.calculateRank(songScore) == 'PERFECT_GOLD'? '+' : '';
        }
        else {
            intendedScore = 0;
            intendedPrecent = 0;
            currentRank = '';
        }

        difficultyTxt.text = songDifficulties.length <= 1? curDifficulty.toUpperCase() : '< ${curDifficulty.toUpperCase()} >';
        trace('$curChar - $curDifficulty - $curVariation - $curCharSel');
        updateText();
    }

    function changeSel(amount:Int) {
        curSel = FlxMath.wrap(curSel + amount, 0, songGroup.members.length - 1);
        for (a => item in songGroup.members) {
            var thingy = a - curSel;
            var scaledY = FlxMath.remapToRange(thingy, 0, 1, 0, 1.3);

            FlxTween.cancelTweensOf(item);
            FlxTween.tween(item, {x: (thingy * 20) + 90, y: (scaledY * 120) + (FlxG.height * 0.48)}, 0.4, {ease: FlxEase.expoOut});
            item.selected = a == curSel;
        }
        if (amount != 0) FunkinSound.playOnce(Paths.sound('scrollMenu'), 0.4);

        FreeplayLogic.lastSongId = songGroup.members[curSel].freeplayData?.data?.id ?? null;
        changeDif(0);
    }

    function updateText() {
        if (!canInteract) return;
        scoreBG.scale.x = scoreTxt.width / 2 + 6;
        scoreBG.updateHitbox();
        scoreBG.x = FlxG.width - scoreBG.width;

        scoreTxt.x = scoreBG.x + 6;
        if (songGroup.members[curSel].freeplayData != null) {
            var precentPortion:String = '';

            lerpScore = MathUtil.snap(MathUtil.smoothLerpPrecision(lerpScore, intendedScore, FlxG.elapsed, 0.2), intendedScore, 1);
            if (intendedPrecent != null) {
                lerpPrecent = MathUtil.snap(MathUtil.smoothLerpPrecision(lerpPrecent, intendedPrecent, FlxG.elapsed, 0.5), intendedPrecent, 1 / 100);
                precentPortion = ' (${(Math.floor(lerpPrecent * 100))}%$currentRank)';
            }
            
            scoreTxt.text = 'PERSONAL BEST: ' + FlxStringUtil.formatMoney(lerpScore, false) + precentPortion;
        }
        else 
            scoreTxt.text = 'PERSONAL BEST: ???';

        difficultyTxt.x = Std.int(scoreBG.x + (scoreBG.width - difficultyTxt.width) / 2);
        difficultyTxt.y = scoreTxt.y + difficultyTxt.height + 10;

        variationTxt.text = 'CURRENT VARIATION: ${(curChar?.toUpperCase() ?? 'NULL')}';
        variationTxt.x = Std.int(scoreBG.x + (scoreBG.width - variationTxt.width) / 2);
        variationTxt.y = difficultyTxt.y + variationTxt.height + 10;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        if (!canInteract) return;
        updateText();

        var pressUP:Bool = controls.UI_UP_P || Math.round(FlxG.mouse.wheel) > 0 || SwipeUtil.flickUp;
        var pressDOWN:Bool = controls.UI_DOWN_P || Math.round(FlxG.mouse.wheel) < 0 || SwipeUtil.flickdown;
        var pressLEFT:Bool = controls.UI_LEFT_P || (FlxG.keys.pressed.CONTROL && FlxG.mouse.justPressedRight);
        var pressRIGHT:Bool = controls.UI_RIGHT_P || (!FlxG.keys.pressed.CONTROL && FlxG.mouse.justPressedRight);
        var pressACCEPT:Bool = controls.ACCEPT || FlxG.mouse.justPressed;

        if (pressUP) changeSel(-1);
        if (pressDOWN) changeSel(1);

        if (pressLEFT) changeDif(-1);
        if (pressRIGHT) changeDif(1);

        if (controls.BACK_P) {
            saveParams(false);
            FlxG.switchState(() -> new MainMenuState());
        }

        if (controls.FREEPLAY_CHAR_SELECT) {
            //canInteract = false;
            //openSubState(new CharacterSelectSubstate());

            curCharSel = FlxMath.wrap(curCharSel + 1, 0, charArray.length - 1);
            curVariation = charArray[curCharSel];
            FreeplayLogic.lastCharacter = curVariation;
            saveParams(false);
            initList();
            changeSel(0);
        }

        if (pressACCEPT) {
            canInteract = false;
            if (curSel == 0 && songGroup.members[curSel].freeplayData == null) {
                var allowedSongs = [];
                for (i in songGroup.members) {
                    var song = i.freeplayData;
                    if (song == null) continue;
                    var charVars:Array<String> = song?.data.getVariationsByCharacterId(curChar) ?? Constants.DEFAULT_VARIATION_LIST;
                    var difAvailable:Array<String> = song?.data.listDifficulties(null, charVars, false) ?? Constants.DEFAULT_DIFFICULTY_LIST_FULL;
                    
                    if (difAvailable.contains(curDifficulty))
                        allowedSongs.push(i);
                }
                curSel = songGroup.members.indexOf(allowedSongs[FlxG.random.int(0, allowedSongs.length - 1)]);
                changeDif(0);
                playSong(true);
            }
            else 
                playSong(false);
        }
    }

    function playSong(random:Bool = false) {
        saveParams(random);
        var songData = songGroup.members[curSel].freeplayData;

        var targetSongNullable:Song = SongRegistry.instance.fetchEntry(songData?.data.id ?? 'unknown', {variation: curVariation});
        if (targetSongNullable == null) return;
        
        var targetSong:Song = targetSongNullable;
        PlayStatePlaylist.campaignId = songData?.levelId ?? null;

        var targetDifficulty:Null<SongDifficulty> = targetSong.getDifficulty(curDifficulty, curVariation);
        if (targetDifficulty == null) return;

        var baseInstrumentalId:String = targetSong?.getBaseInstrumentalId(curDifficulty, targetDifficulty.variation ?? Constants.DEFAULT_VARIATION) ?? '';

        Paths.setCurrentLevel(songData?.levelId);
        LoadingState.loadPlayState(
        {
            targetSong: targetSong,
            targetDifficulty: curDifficulty,
            targetVariation: curVariation,
            targetInstrumental: baseInstrumentalId,
            practiceMode: false,
            minimalMode: false,
            botPlayMode: false
        }, true);
    }

    function saveParams(random:Bool = false) {
        FreeplayLogic.lastSongId = (songGroup.members[curSel].freeplayData != null && !random)? songGroup.members[curSel].freeplayData.data.id : null;
        FreeplayLogic.lastDifficulty = curDifficulty;
        FreeplayLogic.lastVariation = curVariation;
    }

    function doTxt(x, y, size) {
        return new FlxText(x, y, 0, '').setFormat(Paths.font("vcr.ttf"), size, -1);
        // var placeholder = new FlxBitmapText(x, y, '', FlxBitmapFont.fromAngelCode(Paths.font("vcr-bmp.png"), Paths.font("vcr-bmp.fnt")));
        // placeholder.antialiasing = false;
        // var scale = size / 16;
        // placeholder.scale.set(scale, scale);
        // return placeholder;
    }
}