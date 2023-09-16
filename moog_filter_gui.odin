package moog_filter

import "core:fmt"
import "core:math"

import ray "vendor:raylib"
import "core:mem"
import "core:c"
import "core:runtime"
import "core:strings"

MAX_SAMPLES            :: 512
MAX_SAMPLES_PER_UPDATE :: 4096

// Cycles per second (hz)
frequency : f64 = 440.0

// Audio frequency, for smoothing
audio_frequency : f64 = 440.0

// Previous value, used to test if sine needs to be rewritten, and to smoothly modulate frequency
old_frequency : f64 = 1.0

// Index for audio rendering
sine_idx : f64 = 0.0

moog_filter_cutoff : f64 = 500.0 // Hz

// AudioCallback :: #type proc "c" (bufferData: rawptr, frames: c.uint)

// Audio input processing callback
audio_input_callback :: proc "c" ( /* void * */ buffer : rawptr, frames : c.uint ) {
    audio_frequency = frequency + (audio_frequency - frequency) * 0.95
    audio_frequency += 1.0
    audio_frequency -= 1.0
    // incr : f64 = audio_frequency / 44100.0
    incr : f64 = audio_frequency / 48000.0
    d_ptr : ^i16  = (^i16)(buffer)

    // Create the buffer of samples to be written.
    data_f64 : [ MAX_SAMPLES_PER_UPDATE ]f64 

    for i := 0; i < int(frames); i += 1 {
      
        data_f64[ i ] = 32000.0 * math.sin( 2 * math.PI * sine_idx )

        // d_ptr^ = i16( 32000.0 * math.sin( 2 * math.PI * sine_idx ) )

        sine_idx += incr
        if sine_idx > 1.0 {
            sine_idx -= 1.0
        }
    }


    context = runtime.default_context()

    // Process a multiple samples.
    data_f64_slice := moog_process( mogg_filter, data_f64[:] )

    // data_f64_slice := data_f64[:]

    // Write the buffer of samples to the output buffer.
    for i := 0; i < int(frames); i += 1 {

        d_ptr = mem.ptr_offset( d_ptr, 1 )
        // d_ptr^ = i16( data_f64[ i ] )
        d_ptr^ = i16( data_f64_slice[ i ] * 16_000.0 )   // jnc:  Adicionei os 32_000.0
    }


    // // Working original translatted from C example to Odin : correct!
    // for i := 0; i < int(frames); i += 1 {
    //  
    //     d_ptr = mem.ptr_offset( d_ptr, 1 )
    //     // d[ i ] = i16(32000.0 * math.sin( 2 * PI * sine_idx ) )
    //     d_ptr^ = i16( 32000.0 * math.sin( 2 * math.PI * sine_idx ) )
    //
    //     sine_idx += incr
    //     if sine_idx > 1.0 {
    //         sine_idx -= 1.0
    //     }
    // }
    
}


mogg_filter : ^MoogLadderFilter = nil

main :: proc () {
    fmt.printf( "Hello, world!" )

    // Create a moog ladder filter.
    // Set initial filter parameters.
    moog_sample_rate := 48000 // 26040 // 44100
    mogg_filter = moog_ladder_filter_create( moog_sample_rate, moog_filter_cutoff /* 500, 2000, 1500 */,
                                             resonance = 0.1, drive = 1.0 )
    defer moog_ladder_filter_destroy( mogg_filter)


    // Set filter parameters during runtime.
    // moog_ladder_filter_set_cutoff( mogg_filter, 1000.0 )
    // moog_ladder_filter_set_resonance( mogg_filter, 0.5 )

    // Create a buffer of 1 second samples with a sine wave off 1000 Hz.
    
    // size : int = sample_rate
    // buffer := make( []f64, size )
    // for i := 0; i < size; i += 1 {
    //     buffer[i] = math.sin( 2.0 * math.PI * 1000.0 * f64( i ) / f64( sample_rate ) )
    // }

    // Process a multiple samples.
    // moog_process( mogg_filter, buffer )


    // Initialization
    //--------------------------------------------------------------------------------------
    screen_width  : i32 = 800
    screen_height : i32 = 450

    ray.InitWindow(screen_width, screen_height, "raylib GUI demo of the moog_ladder_filter in Odin");

    ray.InitAudioDevice();              // Initialize audio device

    ray.SetAudioStreamBufferSizeDefault( MAX_SAMPLES_PER_UPDATE )

    // Init raw audio stream (sample rate: 44100, sample size: 16bit-short, channels: 1-mono)
    // stream : ray.AudioStream = ray.LoadAudioStream(44100, 16, 1)
    stream : ray.AudioStream = ray.LoadAudioStream(48000, 16, 1)

    ray.SetAudioStreamCallback(stream, audio_input_callback )

    // Buffer for the single cycle waveform we are synthesizing
    // short *data = (short *)malloc(sizeof(short)*MAX_SAMPLES);
    data : ^[ MAX_SAMPLES ]i16 = new( [ MAX_SAMPLES ]i16 )
    defer free( data )

    // Frame buffer, describing the waveform when repeated over the course of a frame
    // short *writeBuf = (short *)malloc(sizeof(short)*MAX_SAMPLES_PER_UPDATE);
    writeBuf : ^[ MAX_SAMPLES_PER_UPDATE ]i16 = new( [ MAX_SAMPLES_PER_UPDATE ]i16 )
    defer free( writeBuf )

    ray.PlayAudioStream( stream )        // Start processing stream buffer (no data loaded currently)


    // Computed size in samples of the sine wave
    wave_length : int = 1


    position : ray.Vector2 = { 0, 0 }

    ray.SetTargetFPS(30);               // Set our game to run at 30 frames-per-second
    
    //--------------------------------------------------------------------------------------

    // Main game loop
    for !ray.WindowShouldClose()    // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------

        // Sample mouse input.
        mouse_position := ray.GetMousePosition()

        if ray.IsMouseButtonDown( ray.MouseButton.LEFT ) {
            fp : f64 = f64( mouse_position.y )
            frequency = 40.0 + f64( fp )

            pan : f64 = f64( mouse_position.x ) / f64( screen_width )
            ray.SetAudioStreamPan( stream, f32(pan) )
        }

        // Rewrite the sine wave
        // Compute two cycles to allow the buffer padding, simplifying any modulation, resampling, etc.
        if frequency != old_frequency {
            // Compute wavelength. Limit size in both directions.
            //int oldWavelength = waveLength;
            // wave_length = int( 22050 / frequency )
            wave_length = int( 24000 / frequency )
            if wave_length > MAX_SAMPLES / 2 {
                wave_length = MAX_SAMPLES / 2
            }
            if (wave_length < 1) {
                wave_length = 1
            }

            // data_ptr := data
            
            // Write sine wave
            for i := 0; i < wave_length * 2; i += 1 {

                // data_ptr = mem.ptr_offset( data_ptr, 1 )
                // data[ i ] = i16( math.sin( ( ( 2 * math.PI * f64( i ) / wave_length ) ) ) * 32000 )
               
                data[i] = i16( math.sin( ( ( 2 * math.PI * f64( i ) /  f64( wave_length ) ) ) ) * 32000 )
            }
            // Make sure the rest of the line is flat
            for j := wave_length * 2; j < MAX_SAMPLES; j += 1 {
                data[ j ] = 0
            }

            // Scale read cursor's position to minimize transition artifacts
            //readCursor = (int)(readCursor * ((float)waveLength / (float)oldWavelength));
            old_frequency = frequency
        }


        // Draw
        //----------------------------------------------------------------------------------
        ray.BeginDrawing();

            ray.ClearBackground( ray.RAYWHITE )

            my_str := fmt.aprintf("sine freq: %v Moog_Ladder_Filter: %v Hz", int(frequency), int(moog_filter_cutoff) )
            defer delete( my_str)
            my_cstr := strings.clone_to_cstring( my_str )
            defer delete( my_cstr )

            ray.DrawText( my_cstr, ray.GetScreenWidth() - 400 /* 220 */, 10, 17 /* 20 */, ray.GRAY )
            ray.DrawText( "Click mouse button to change freq. or pan", 10, 10, 17 /* 20 */, ray.DARKGRAY)

            // Draw the current buffer state proportionate to the screen
            for i := 0; i < int( screen_width ); i += 1 {
                position.x = f32( i )
                position.y = f32( 250 + 50 * data[ i * MAX_SAMPLES / int( screen_width ) ] / ( 32000.0 / 40 ) )

                ray.DrawPixelV( position, ray.GRAY )
            }

        ray.EndDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    
    // free(data);                 // Unload sine wave data
    // free(writeBuf);             // Unload write buffer

    ray.UnloadAudioStream(stream)   // Close raw audio stream and delete buffers from RAM
    ray.CloseAudioDevice()         // Close audio device (music streaming is automatically stopped)

    ray.CloseWindow()              // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

    // moog_ladder_filter_destroy( mogg_filter)

}

