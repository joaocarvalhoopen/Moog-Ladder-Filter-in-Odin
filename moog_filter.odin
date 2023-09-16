// This is a port of the Moog filter from:
//
//
// 
// GitHub - mwcm - MoogFilter
//
// https://github.com/mwcm/MoogFilter
//
package moog_filter

import "core:math"
import "core:fmt"


// Thermal voltage (26 miliwatts at room temp)
VT :: 0.312
MOOG_PI :: 3.14159265358979323846264338327950288


MoogLadderFilter :: struct {
    sample_rate : int,
    cutoff      : f64,
    resonance   : f64,
    drive       : f64,
    x  : f64,
    g  : f64,
    V  : [4]f64,
    dV : [4]f64,
    tV : [4]f64,
}

// TODO: What should default sample rate be? 44100? 48000?
// TODO: What should default cutoff be?
moog_ladder_filter_create :: proc ( sample_rate : int = 26040, cutoff : f64 = 1500,
                                  resonance : f64 = 0.1, drive : f64 = 1.0 ) -> ^MoogLadderFilter {

    moog_filter := new( MoogLadderFilter)
    
    moog_filter.sample_rate = sample_rate
    // moog_filter.cutoff = cutoff
    moog_filter.resonance = resonance
    moog_filter.drive = drive
    moog_filter.x = 0
    moog_filter.g = 0
    moog_filter.V  = { 0, 0, 0, 0 }
    moog_filter.dV = { 0, 0, 0, 0 }
    moog_filter.tV = { 0, 0, 0, 0 }
    moog_set_cutoff( moog_filter, cutoff )

    return moog_filter
}

moog_ladder_filter_destroy :: proc ( moog : ^MoogLadderFilter ) {
    free( moog )
}

// Should likely put limits on this (ie 4 > res > 0)
moog_set_resonance :: proc ( moog : ^MoogLadderFilter, res : f64 ) {
    moog.resonance = res
}

moog_get_resonance :: proc ( moog : ^MoogLadderFilter ) -> f64 {
    return moog.resonance
}

moog_set_cutoff :: proc ( moog : ^MoogLadderFilter, cutoff : f64 ) {
    moog.cutoff = cutoff
    moog.x = ( MOOG_PI * cutoff ) / f64(moog.sample_rate)
    moog.g = 4.0 * MOOG_PI * VT * cutoff * (1.0 - moog.x) / (1.0 + moog.x)
}

moog_get_cutoff :: proc ( moog : ^MoogLadderFilter ) -> f64 {
    return moog.cutoff
}

moog_process :: proc (moog : ^MoogLadderFilter, samples :  []f64 ) -> []f64 {
    // We will be writting on the samples.
    samples := samples
    if moog == nil {
        fmt.printf( "moog_process: moog is nil\n" )
        return samples
    }
    
    dV0 : f64 = 0.0
    dV1 : f64 = 0.0
    dV2 : f64 = 0.0
    dV3 : f64 = 0.0

    sample_rate_f64 : f64 = f64( moog.sample_rate )

    for s, i in samples {
        dV0 = -moog.g * ( math.tanh( ( moog.drive * samples[ i ] + moog.resonance * moog.V[ 3 ]) / ( 2.0 * VT ) ) + moog.tV[ 0 ] )
        moog.V[ 0 ] += ( dV0 + moog.dV[ 0 ] ) / ( 2.0 * sample_rate_f64 )
        moog.dV[ 0 ] = dV0
        moog.tV[ 0 ] = math.tanh(moog.V[ 0 ] / ( 2.0 * VT ) )
        
        dV1 = moog.g * ( moog.tV[ 0 ] - moog.tV[ 1 ] )
        moog.V[ 1 ] += ( dV1 + moog.dV[ 1 ] ) / ( 2.0 * sample_rate_f64 )
        moog.dV[ 1 ] = dV1
        moog.tV[ 1 ] = math.tanh( moog.V[ 1 ] / ( 2.0 * VT ) )
        
        dV2 = moog.g * ( moog.tV[ 1 ] - moog.tV[ 2 ] )
        moog.V[ 2 ] += ( dV2 + moog.dV[ 2 ] ) / ( 2.0 * sample_rate_f64 )
        moog.dV[ 2 ] = dV2
        moog.tV[ 2 ] = math.tanh( moog.V[ 2 ] / ( 2.0 * VT ) )
        
        dV3 = moog.g * ( moog.tV[ 2 ] - moog.tV[ 3 ] )
        moog.V[ 3 ] += ( dV3 + moog.dV[ 3 ] ) / ( 2.0 * sample_rate_f64 )
        moog.dV[ 3 ] = dV3
        moog.tV[ 3 ] = math.tanh( moog.V[ 3 ] / ( 2.0 * VT ) )
        
        samples[ i ] = moog.V[ 3 ]
    }

    return samples
}

