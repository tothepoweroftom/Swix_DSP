//
//  Doppler.swift
//  AudInt_2
//
//  Created by Tom Power on 13/02/2017.
//  Copyright © 2017 MOBGEN:Lab. All rights reserved.
//

import Foundation

protocol DopplerDelegate: class {
    
    func dopplerDidStart(_ sender: Doppler )
//    func onRead(sender: Doppler)
    func dopplerDidEnd(_ sender: Doppler)
        //Do stuff when frames are read
    
    //Gestures
    func onPush(_ sender: Doppler)
    func onPull(_ sender: Doppler)
    func onTap(_ sender: Doppler)
    func onDoubleTap(_ sender: Doppler)
    func onNothing(_ sender: Doppler)
    
}



class Doppler {
    
    //Analysis Variables

    var leftBand = 0
    var rightBand = 0
    
    var fftSize = N
    var sampleRate = 44100.0
    
    //Frequency bins are scanned until the amp drops below 1% of the peak amp
    var maxVolRatio = 0.1
    var RELEVANT_FREQ_WINDOW = 17
    var SECOND_PEAK_RATIO = 0.3
    

    
    //AUDIOKIT PARAMETERS
    var frequency = 19000.0
    var amplitude = 1.0
    var freqIndex: Int!
    var fftData = [Double]()
    var velocity = 0
    var velLabel = ["none", "slow", "medium", "fast"]
    
    //Delegates
    var delegate: DopplerDelegate!
    
    //GESTURE DETECTION
    var previousDirection = 0
    var directionChanges = 0
    var cyclesLeftToRead = -1
    var cyclesToRefresh = 0
    var cyclesToRead = 5
    
    
    //Booleans
    var calibrate = false
    var repeater = false
    
    init(frequency: Double){
        self.frequency = frequency
        freqIndex = freqToIndex(self.frequency, fftSize: fftSize, sampleRate: sampleRate)
        print(freqIndex)
        print(indexToFreq(freqIndex, fftSize: fftSize, sampleRate: sampleRate))
        
        
        
    }
    
    func start(){
 
        delegate?.dopplerDidStart(self)

        
    }
    
    func stop(){

        delegate?.dopplerDidEnd(self)
        
    }
    
    func update(fftData: [Double]) {
        self.fftData = fftData

        
        if (calibrate) {
            optimizeFrequency(minFreq: 18000, maxFreq: 21000)
        } else {
            let bandwidths = self.getBandwidth()
            self.leftBand = bandwidths[0]
            self.rightBand = bandwidths[1]
            
//            print(bandwidths)
            
            
            calculateGestures()
            
        }
        
    }
    
    func getBandwidth() -> [Int] {
        //setup variables

        let bin = freqIndex
        var normalizedVolume = 0.0
        let binVolume = fftData[bin!]
        
        
        //LEFT Bandwidth -- First Scan

        var leftBandwidth = 0

        repeat {
            leftBandwidth += 1
            let volume = fftData[bin! - leftBandwidth] as Double
            normalizedVolume = volume/binVolume
        } while (normalizedVolume > maxVolRatio && leftBandwidth < RELEVANT_FREQ_WINDOW )
        
//        //LEFT Bandwidth -- Second Scan
        var secondaryScanFlag = 0
        var secondaryLeftBandwidth = leftBandwidth
        repeat {
                secondaryLeftBandwidth+=1
                let volume = fftData[bin!-secondaryLeftBandwidth]
                normalizedVolume = volume/binVolume
                    if (normalizedVolume > SECOND_PEAK_RATIO) {
                        secondaryScanFlag = 1
                    }
        
                    if (secondaryScanFlag == 1 && normalizedVolume < maxVolRatio ) {
                        break
                    }
                    
        } while (secondaryLeftBandwidth < RELEVANT_FREQ_WINDOW)
        
        //RIGHT Bandwidth -- First Scan
        
        var rightBandwidth = 0
        
        repeat {
            rightBandwidth+=1
            let volume = fftData[bin! + rightBandwidth]
            normalizedVolume = volume/binVolume
        } while(normalizedVolume > maxVolRatio && rightBandwidth < RELEVANT_FREQ_WINDOW)
        
//        //RIGHT Bandwidth -- Second Scan
        secondaryScanFlag = 0
        var secondaryRightBandwidth = 0
        
        repeat {
                secondaryRightBandwidth+=1
                let volume = fftData[bin!+secondaryRightBandwidth]
                normalizedVolume = volume/binVolume
    
                if (normalizedVolume > SECOND_PEAK_RATIO) {
                    secondaryScanFlag = 1
                }
        
                if (secondaryScanFlag == 1 && normalizedVolume < maxVolRatio ) {
                    break
                }
                    
        } while (secondaryRightBandwidth < RELEVANT_FREQ_WINDOW)

        if (secondaryScanFlag == 1) {
            rightBandwidth = secondaryRightBandwidth
        }
        
        
        
        
      return [leftBandwidth, rightBandwidth]
        
    }
    
    func calculateGestures(){
        
        if(cyclesToRefresh>0) {
            cyclesToRefresh -= 1
            return
        }

        
        if (leftBand > 4 || rightBand > 4) {
            let difference = leftBand - rightBand
            var direction = difference.sign()
            
            //Gestures
//            if(direction == 1) {
//                print("Direction: Postive")
//            } else if (direction == -1) {
//                print("Direction: Negative")
//            } else {
//                print("Direction: None")
//            }
            
            //Scan over a four frame window
            if (direction != 0 && direction != previousDirection) {
                cyclesLeftToRead = cyclesToRead
                previousDirection = direction
                directionChanges += 1
            }
        }
         cyclesLeftToRead -= 1
        
        
        
        if (cyclesLeftToRead == 0) {
            if (directionChanges == 1) {
                
                if (previousDirection == -1) {
                    delegate?.onPush(self)
//                    print("Push")
                } else {
                    delegate?.onPull(self)
//                    print("Pull")

                }
                
            } else if ( directionChanges == 2 ) {
                
                delegate?.onTap(self)
//                print("Tap")
                
            } else {
                delegate?.onDoubleTap(self)
//                print("DoubleTap")
            }
            previousDirection = 0
            directionChanges = 0
            cyclesToRefresh = cyclesToRead
        } else {
            delegate?.onNothing(self)
//            print("_")
        }
        
    }
    
    func setFrequency(freq: Double){
        self.frequency = freq
    }
    
    func optimizeFrequency(minFreq: Double, maxFreq: Double) {
        let minInd = freqToIndex(minFreq, fftSize: 1024, sampleRate: 44100.0)
        let maxInd = freqToIndex(maxFreq, fftSize: 1024, sampleRate: 44100.0)
        
        var primaryIndex = freqIndex
        
        for var i in minInd...maxInd {
            if(fftData[i] > fftData[primaryIndex!]) {
                primaryIndex = i
            }
        }
        
        self.setFrequency(freq: indexToFreq(primaryIndex!, fftSize: fftSize, sampleRate: 44100.0))
        print("Calibrated: " + "\(indexToFreq(primaryIndex!, fftSize: fftSize, sampleRate: 44100.0))")
        self.calibrate = false

    }
    
    
    
    
    
}