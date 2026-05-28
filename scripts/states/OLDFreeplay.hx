import flixel.FlxG;
import flixel.text.FlxText;
import flixel.text.FlxBitmapFont;
import flixel.text.FlxBitmapText;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxStringUtil;

import funkin.ui.MusicBeatState;
import funkin.data.song.SongRegistry;
import funkin.data.story.level.LevelRegistry;
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
import funkin.play.scoring.Scoring;

#if FEATURE_DISCORD_RPC
import funkin.api.discord.DiscordClient;
#end

import funkin.util.SwipeUtil;
import funkin.util.TouchUtil;
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.ui.FunkinButton;

import StringTools;

class OLDfreeplay extends MusicBeatState {

    var canInteract:Bool = true;
    var curSel:Int = 0;
    var curCharSel:Int = 0;

    var curDifficulty:String = 'hard';
    var curVariation(never, set):String = 'bf';
    function set_curVariation(value:String):String {
        curVariation = value;
        curChar = (value == 'default' || Constants.DEFAULT_DIFFICULTY_LIST_FULL.contains(value))? charArray[curCharSel] : curVariation;
        FreeplayState.rememberedCharacterId = curChar;
        return curVariation;
    }
    var curChar:String = 'bf';
    var curRank:String = '';

    var intendedScore:Float = 0;
    var lerpScore:Float = 0;
    var intendedPrecent:Float = 0;
    var lerpPrecent:Float = 0;

    var songGroup:FlxTypedGroup<FreeplayMenuItem> = new FlxTypedGroup();
    var charArray:Array<String> = [];

    var bg:FreeplayBG;
    var scoreTxt:FlxText;
    var scoreBG:FunkinSprite;
    var difficultyTxt:FlxText;
    var variationTxt:FlxText;

    var backButton:FunkinBackButton;

    var stickerState = null;

    function new(?stickers:StickerSubState) {
        super();
        this.stickerState = stickers;
    }

    override function create() {
        super.create();

        #if FEATURE_DISCORD_RPC
        DiscordClient.setPresence({state: 'In the Menus', details: null});
        #end

        curDifficulty = FreeplayLogic.lastDifficulty;
        curVariation = FreeplayLogic.lastVariation;

        for (character in PlayerRegistry.instance.listEntryIds()) charArray.push(character);
        curCharSel = charArray.indexOf(FreeplayLogic.lastCharacter);

        curChar = charArray[curCharSel];
        FreeplayState.rememberedCharacterId = curChar;

        persistentUpdate = true;
        persistentDraw = true;

        if (stickerState != null) {
            openSubState(stickerState);
            stickerState.degenStickers();
        }

        FunkinSound.playMusic('freakyMenu', {
            overrideExisting: true,
            restartTrack: false,
            persist: true
        });

        initUI();
        initList();
    }

    function initUI() {
        bg = new FreeplayBG(charArray[curCharSel]);
        add(bg);

        scoreBG = new FunkinSprite().makeSolidColor(Std.int(FlxG.width * 0.35), 91, 0xFF000000);
        scoreBG.alpha = 0.6;
        add(scoreBG);

        scoreTxt = doTxt(FlxG.width * 0.7, 5, 32);
        add(scoreTxt);

        difficultyTxt = doTxt(0, scoreTxt.y + 36, 24);
        add(difficultyTxt);
        
        variationTxt = doTxt(0, difficultyTxt.y + 36, 18);
        add(variationTxt);

        insert(members.indexOf(bg) + 1, songGroup);

        if (FlxG.onMobile) {
            backButton = new FunkinBackButton(0, FlxG.height * 0.9, -1, function() {
                saveParams(false);
                FlxG.switchState(() -> new MainMenuState());
            });
            backButton.setPosition(FlxG.width - backButton.width - 20, FlxG.height - backButton.height - 20);
            add(backButton);
        }
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
            var item = new FreeplayMenuItem();
            if (song != null) {
                // this is so stupid, but i have to do this so that it can show the icon of the opponent for the custom difficulties
                FreeplayState.rememberedDifficulty = song.data.listDifficulties(null, ['default'], false, false)[0];
                item.initData(song);
            }
            else 
                item.txt.text = 'random';
            
            songGroup.add(item);
        }

        curSel = 0;
        for (a => i in songGroup.members) {
            if (i.freeplayData != null && i.freeplayData.data.id == FreeplayLogic.lastSongId) {
                curSel = a;
                break;
            }
        }

        changeSel(0);
        bg.setBG(charArray[curCharSel]);
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
        if (songDifficulties.length <= 1) difIndex -= amount;
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

            curRank = Scoring.calculateRank(songScore) == 'PERFECT_GOLD'? '+' : '';
        }
        else {
            curVariation = charArray[curCharSel];
            intendedScore = 0;
            intendedPrecent = 0;
            curRank = '';
        }

        difficultyTxt.text = songDifficulties.length <= 1? curDifficulty.toUpperCase() : '< ${curDifficulty.toUpperCase()} >';
        //trace('$curChar - $curDifficulty - $curVariation - $curCharSel');
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
        if (songGroup.members[curSel] != null && songGroup.members[curSel].freeplayData != null) {
            var precentPortion:String = '';

            lerpScore = MathUtil.snap(MathUtil.smoothLerpPrecision(lerpScore, intendedScore, FlxG.elapsed, 0.2), intendedScore, 1);
            if (intendedPrecent != null) {
                lerpPrecent = MathUtil.snap(MathUtil.smoothLerpPrecision(lerpPrecent, intendedPrecent, FlxG.elapsed, 0.5), intendedPrecent, 1 / 100);
                precentPortion = ' (${(Math.floor(lerpPrecent * 100))}%$curRank)';
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

        var pressUP:Bool;
        var pressDOWN:Bool;
        var pressLEFT:Bool;
        var pressRIGHT:Bool;
        var pressACCEPT:Bool;
        var pressTAB:Bool;

        if (!FlxG.onMobile) {
            pressUP = controls.UI_UP_P || Math.round(FlxG.mouse.wheel) > 0;
            pressDOWN = controls.UI_DOWN_P || Math.round(FlxG.mouse.wheel) < 0;
            pressLEFT = controls.UI_LEFT_P || (FlxG.keys.pressed.CONTROL && FlxG.mouse.justPressedRight);
            pressRIGHT = controls.UI_RIGHT_P || (!FlxG.keys.pressed.CONTROL && FlxG.mouse.justPressedRight);
            pressACCEPT = controls.ACCEPT || FlxG.mouse.justPressed;
            pressTAB = controls.FREEPLAY_CHAR_SELECT;
        }
        else {
            pressUP = SwipeUtil.flickUp;
            pressDOWN = SwipeUtil.flickdown;
            pressRIGHT = difficultyTxt != null && TouchUtil.justPressed && TouchUtil.overlapsComplex(difficultyTxt);
            pressTAB = variationTxt != null && TouchUtil.justPressed && TouchUtil.overlapsComplex(variationTxt);
        }

        if (pressUP) changeSel(-1);
        if (pressDOWN) changeSel(1);

        if (pressLEFT) changeDif(-1);
        if (pressRIGHT) changeDif(1);

        if (pressTAB) {
            var amount = FlxG.keys.pressed.CONTROL? -1 : 1;
            curCharSel = FlxMath.wrap(curCharSel + amount, 0, charArray.length - 1);
            curVariation = charArray[curCharSel];
            FreeplayLogic.lastCharacter = curVariation;
            saveParams(false);
            initList();
            changeSel(0);
        }

        if (controls.BACK_P) {
            saveParams(false);
            FlxG.switchState(() -> new MainMenuState());
        }

        if (pressACCEPT) selectSong();

        if (FlxG.onMobile && TouchUtil.justReleased && !SwipeUtil.justSwipedAny) {
            var touchX:Float = -1;
            var touchY:Float = -1;
            if (FlxG.touches.list.length > 0) {
                for (t in FlxG.touches.list) {
                    if (t.justReleased) {
                        touchX = t.x;
                        touchY = t.y; 
                        break;
                    }
                }
            }

            var onScorePanel:Bool = scoreBG != null && touchX >= scoreBG.x && touchY <= scoreBG.y + scoreBG.height + 10;

            //var onDiffText:Bool = (difficultyTxt != null && TouchUtil.overlapsComplex(difficultyTxt))
            //    || (variationTxt != null && TouchUtil.overlapsComplex(variationTxt));

            if (touchY >= 0 && !onScorePanel) {
                var songSpacing:Float = 120;
                var songCentreY:Float = FlxG.height * 0.48;
                var maxHitDist:Float = songSpacing * 0.5;
                var nearest:Int = -1;
                var nearestDist:Float = maxHitDist;

                for (i in 0...songGroup.members.length) {
                    var thingy = i - curSel;
                    var scaledY = FlxMath.remapToRange(thingy, 0, 1, 0, 1.3);
                    var targetY:Float = (scaledY * songSpacing) + songCentreY;
                    var dist:Float = Math.abs(targetY - touchY);
                    if (dist < nearestDist) {
                        nearestDist = dist;
                        nearest = i;
                    }
                }

                if (nearest >= 0) {
                    if (nearest != curSel) changeSel(nearest - curSel);
                    else selectSong();
                }
            }
        }
    }

    function selectSong() {
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

            if (songGroup.members[curSel] == null) {
                canInteract = true;
                curSel = 0;
                return;
            }

            changeDif(0);
            playSong(true);
        }
        else 
            playSong(false);
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