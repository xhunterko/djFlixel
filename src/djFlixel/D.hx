/********************************************************************
 * DJFLIXEL Main Static Helper Class
 * ---------------------------------
 * 
 * - Call D.init() before creating the FlxGame()
 * - Provides general purpose tools
 * 
 *******************************************************************/

package djFlixel;

import djFlixel.core.*;
import djfl.util.BitmapUtil;
import djA.DataT;
import djA.Macros;
import flixel.FlxG;
import flixel.FlxObject;
import openfl.Lib;
import openfl.display.Preloader.DefaultPreloader;
import openfl.filters.BitmapFilterShader;
import haxe.Log;

#if ( !flash && !canvas)
	import openfl.filters.BitmapFilter;
	import openfl.filters.BlurFilter;
	import openfl.filters.ConvolutionFilter;
#end


class D
{
	/** Defined in djFlixel `include.xml` */
	public inline static var DJFLX_VER:String = Macros.getDefine("DJFLX_VER");
	
	/** Application info and starting parameters.
	    Set new ones with D.init(..)
	**/
	public static var INFO(default,null) = {
		name:"djflixel_app",	// Used for log infos
		version:"0.1",			// Used for log infos
		website:"",				// General Purpose, not used
		// ------
		volume: -1,				// float (0 to 1), if >0 Will set global flixel volume to this 
		fullscreen:false,		// Start fullscreen
		smoothing:false,		// Soft pixels
		savename:"",			// OPTIONAL - Savegame ID, make sure it is unique among djflixel projects
		// ------
		debug_keys:false		// Enable `D._debug_keys()` 
	};
	
	/** Sound System */
	public static var snd(default, null):Dsound;
	/** Control System */
	public static var ctrl(default, null):Dcontrols;
	/** Save System */
	public static var save(default, null):Dsave;
	/** Asset System */
	public static var assets(default, null):Dassets;
	/** Destroy helper */
	public static var dest(default, null):Ddest;
	/** Text gen */
	public static var text(default, null):Dtext;
	/** Align functions */
	public static var align(default, null):Dalign;
	/** UI functions */
	public static var ui(default, null):Dui;
	/** Bitmap manipulation utilities */
	public static var bmu(default, null):BitmapUtil;
	/** Other GFX utilities (flixel/djflixel) specific */
	public static var gfx(default, null):Dgfxutil;
	
	// For hashlink, webgl and other targets do the screen softening with a blurfilter
	// rather than the builtin Smoothing, because it can lead to some glitches
	// especially in tilemaps. Flash and HTML Canvas seem to be OK with the build in smoothing method.
	#if (!flash && !canvas)
		static var filters:Array<BitmapFilter>;
		static var bf:BlurFilter;
	#end
	
	/** Depends on fullscreen size, how big the window can get in zoom increments */
	public static var MAX_WINDOW_ZOOM(default, null):Int = 1;
	
	/** Current Antialiasing on/off, comes with a setter that applies to all cameras */
	public static var SMOOTHING(default, set):Bool = false;
	
	/** 
	 * Initialize this static class
	 * @param O You can override fields of `D.INFO` check in code
	 **/
	public static function init(?O:Dynamic)
	{
		if (dest != null) return; // Check if is already inited
			
		DataT.copyFields(O, INFO);
		trace('\n:: DjFlixel v$DJFLX_VER\n:: ${INFO.name}, ${INFO.version}\n:: ----------------------------');
			var c = Lib.current.stage.window.context;
			trace(':: Renderer :', c.type, c.attributes);
		
		dest = new Ddest();
		snd = new Dsound();
		assets = new Dassets();
		text = new Dtext();
		align = new Dalign();
		ui = new Dui();
		bmu = new BitmapUtil();
		
		if (INFO.savename != "") {
			save = new Dsave(INFO.savename);
		}
		
		#if ( !flash && !canvas)
			bf = new BlurFilter(1, 1, 1);	// Going to be set properly at "onResize()" which is automatically called
			filters = [ bf ];
		#end
		
		FlxG.signals.postStateSwitch.add(onStateSwitch);
		FlxG.signals.gameResized.add(onResize);
		
		// :: Some code that needs to run after flxgame is created
		FlxG.signals.preGameStart.addOnce(()->{
			MAX_WINDOW_ZOOM = Math.floor(Lib.current.stage.fullScreenWidth / FlxG.width) - 1;
			SMOOTHING = INFO.smoothing;
			if (INFO.volume >= 0) snd.setVolume(null, INFO.volume);
			FlxG.mouse.useSystemCursor = true;
			FlxG.fullscreen = INFO.fullscreen;
			ctrl = new Dcontrols(); // This needs to init after new FlxGame
		});
		
		#if debug
		if (INFO.debug_keys) {
			trace('Debug : Enabling Debug keys');
			FlxG.signals.postUpdate.add(_debug_keys);
		}
		#end
	}//---------------------------------------------------;
	
	
	static function set_SMOOTHING(value:Bool):Bool
	{
		SMOOTHING = value;
		
		#if (flash || canvas)
		for (i in FlxG.cameras.list) {
			i.antialiasing = SMOOTHING;
		}
		#else
			if (SMOOTHING) {
				FlxG.game.setFilters(filters);
			}else{
				FlxG.game.setFilters([]);
			}
		#end
		return value;
	}//---------------------------------------------------;
	
	// --
	// Gets called right after the new state is created
	static function onStateSwitch()
	{
		#if (flash || canvas)
			// Force the cameras to use the default smoothing (with setter)
			SMOOTHING = SMOOTHING;
		#end
		
		#if debug
			DEBUG_RELOADED = false;
		#end
	}//---------------------------------------------------;
	
	static function onResize(x, y)
	{
		// Recalculate the blur filter to match the new window size?
		#if ( !flash && !canvas)
			var rx = (x / FlxG.width);
			var ry = (y / FlxG.height);
			if (rx <= 1) bf.blurX = 0; else {
				bf.blurX = rx * 0.5;
				if (bf.blurX > 1.6) bf.blurX = 1.6;
			}
			if (ry <= 1) bf.blurY = 0; else {
				bf.blurY = ry * 0.5;
				if (bf.blurY > 1.6) bf.blurY = 1.6;
			}
		#end
	}//---------------------------------------------------;
	
	
	/**
	   Set Windows mode, Disabled fullscreen
	   @param	zoom 1,2,3,4...
	**/
	public static function setWindowed(zoom:Int)
	{
		FlxG.fullscreen = false;
		FlxG.stage.window.width = Math.floor(FlxG.width * zoom);
		FlxG.stage.window.height = Math.floor(FlxG.height * zoom);
		//trace("-- Windowed mode set : ", zoom, FlxG.stage.window.width, FlxG.stage.window.height);
	}//---------------------------------------------------;
	
	
	
	#if debug
	
	/** Read this var to check whether the current state was reloaded with F12, useful in some cases */
	public static var DEBUG_RELOADED:Bool = false;
	/**
	 * Debug keys, autocalled on update.
	 * F12 : Reload external files and reset state
	 * SHIFT F12 : Reset Game
	 * F9 : Antialiasing toggle
	 */
	static function _debug_keys()
	{
		if (FlxG.keys.justPressed.F12) {
			if (FlxG.keys.pressed.SHIFT){
				FlxG.resetGame();
			}else{
				#if DYN_ASSETS
				FlxG.signals.preStateSwitch.addOnce( ()->{ DEBUG_RELOADED = true; });
				assets.reload( FlxG.resetState );
				#end
			}
		}else
		if (FlxG.keys.justPressed.F9) {
			SMOOTHING = !SMOOTHING;
		}
	}//---------------------------------------------------;
	
	#end 
	
}// --