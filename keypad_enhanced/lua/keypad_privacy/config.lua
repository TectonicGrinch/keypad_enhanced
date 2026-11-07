-- Server-managed font catalogue. Put .ttf files in this addon's resource/fonts/.
-- Use the font's internal family name, not its filename. Restart after editing.
return {
    Fonts = {
        {id='default', name='Classic', family='Roboto'},
        {id='gothic', name='Gothic', family='Keypad Enhanced Gothic', file='resource/fonts/keypad_cinzel_latin.ttf'},
        {id='serif', name='PT Serif', family='Keypad Enhanced Serif', file='resource/fonts/keypad_ptserif_latin.ttf'},
        {id='typewriter', name='Cousine (typewriter)', family='Keypad Enhanced Mono', file='resource/fonts/keypad_cousine_latin.ttf'},
        {id='ptsans', name='PT Sans', family='Keypad Enhanced Sans', file='resource/fonts/keypad_ptsans_latin.ttf'},
        {id='lato', name='Lato', family='Keypad Enhanced Humanist', file='resource/fonts/keypad_lato_latin.ttf'},
        {id='oxygen', name='Oxygen', family='Keypad Enhanced Rounded', file='resource/fonts/keypad_oxygen_latin.ttf'},
        {id='abel', name='Abel', family='Keypad Enhanced Narrow', file='resource/fonts/keypad_abel_latin.ttf'},
        {id='play', name='Play', family='Keypad Enhanced Square', file='resource/fonts/keypad_play_latin.ttf'},
        {id='questrial', name='Questrial', family='Keypad Enhanced Geometric', file='resource/fonts/keypad_questrial_latin.ttf'},
        -- {id='myfont', name='My font', family='My Font', file='resource/fonts/myfont.ttf'},
    },
    MaxImageBytes = 1024 * 1024,
    MaxImageDimension = 2048,
    MaxCachedImages = 32,
}
