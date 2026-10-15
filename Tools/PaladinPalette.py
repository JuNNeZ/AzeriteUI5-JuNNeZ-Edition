"""Colour-only finishing grade for existing Paladin metal paintings.

Never changes alpha, geometry, source artwork or functional fill/glass pixels.
Material luminance variation retains the painting's facets, grain and lighting.
"""
import numpy as np

CASES = {'actionbutton-border','actionbutton-border-square','actionbutton-border-square-rounded',
         'pw_crystal_case','pw_crystal_case_low','hp_cap_case','hp_mid_case','hp_low_case','hp_boss_case',
         'hp_critter_case','hp_critter_case_hi','cast_back','cast_back_spiked','cast_back_wooden',
         'minimap-border','minimap-onebar-backdrop','minimap-twobars-backdrop'}
ORNAMENTS = {'minimap-north'}
SILVER = np.array([95.,96.,99.])
GOLD = np.array([130.,102.,46.])
LUMA = np.array([.2126,.7152,.0722])


def grade(pixels, allowed):
    rgb = pixels[:,:,:3].astype(float)
    lum = rgb @ LUMA
    sat = (rgb.max(2)-rgb.min(2))/np.maximum(rgb.max(2),1)
    silver = allowed & (sat < .22)
    gold = allowed & (rgb[:,:,0] > rgb[:,:,2]*1.3) & (rgb[:,:,1] > rgb[:,:,2]*1.15)
    result = rgb.copy()
    for region,palette in ((silver,SILVER),(gold,GOLD)):
        samples = region & (lum > 40)
        if np.count_nonzero(samples) < 8:
            raise ValueError('Insufficient painted metal samples for colour grade')
        reference = float(np.median(lum[samples]))
        corrected_lum = lum*(palette @ LUMA)/reference
        colour = corrected_lum[:,:,None]*palette[None,None,:]/(palette @ LUMA)
        if palette is GOLD:
            # Preserve pale polished highlights; midtone gold shares one warmth.
            shine = np.clip((corrected_lum-150)/90,0,1)[:,:,None]
            colour = colour*(1-shine)+corrected_lum[:,:,None]*shine
        result[region] = colour[region]
    pixels[:,:,:3] = np.clip(result,0,255).astype('uint8')
    return pixels
