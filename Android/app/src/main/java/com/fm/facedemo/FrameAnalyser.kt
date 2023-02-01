/*
 * Copyright 2021 Shubham Panchal
 * Licensed under the Apache License, Version 2.0 (the "License");
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.fm.facedemo

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.util.Log
import android.view.View
import android.widget.TextView
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.fm.face.Activator
import com.fm.face.FaceBox
import com.fm.face.FaceDetector
import com.fm.face.LiveDetector
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext


// Analyser class to process frames and produce detections.
class FrameAnalyser( private var context: Context ,
                     private var boundingBoxOverlay: BoundingBoxOverlay,
                     private var viewBackgroundOfMessage: View,
                     private var textViewMessage: TextView
                     ) : ImageAnalysis.Analyzer {

    // Used to determine whether the incoming frame should be dropped or processed.
    companion object {
        private const val LIVENESS_THRESHOLD = 0.5f
        private val TAG = FrameAnalyser::class.simpleName
    }

    private var isProcessing = false

    @SuppressLint("UnsafeOptInUsageError")
    override fun analyze(image: ImageProxy) {
        // If the previous frame is still being processed, then skip this frame
        if(Activator.getActivation() != Activator.ACTIVATE_SUCCESS) {
            image.close()
            return
        }

        if ( isProcessing ) {
            image.close()
            return
        }
        else {
            isProcessing = true

            // Rotated bitmap for the FaceNet model
            val frameBitmap = BitmapUtils.imageToBitmap( image.image!! , image.imageInfo.rotationDegrees )

            // Configure frameHeight and frameWidth for output2overlay transformation matrix.
            if ( !boundingBoxOverlay.areDimsInit ) {
                boundingBoxOverlay.frameHeight = frameBitmap.height
                boundingBoxOverlay.frameWidth = frameBitmap.width
            }

            var livenessScore = 0.0f;
            var messageString = ""
            val faceResult: List<FaceBox>? = FaceDetector.detect(frameBitmap)
            if(!faceResult.isNullOrEmpty()) {
                if(faceResult!!.size == 1) {

//                    val faceWidth = faceResult!!.get(0).right - faceResult!!.get(0).left
//                    val minFrameWidth = Math.min(frameBitmap.width, frameBitmap.height)
//
//                    if(faceWidth < minFrameWidth * 0.5f) { //reject small face
//                        boundingBoxOverlay.livenessResult = 2
//                        messageString = "Small face detected!"
//                    } else {
                        livenessScore = LiveDetector.check(frameBitmap, faceResult!!.get(0))
                        Log.e(TAG, "liveness score " + livenessScore)
                        if(livenessScore > LIVENESS_THRESHOLD) {
                            boundingBoxOverlay.livenessResult = 1
                        } else {
                            boundingBoxOverlay.livenessResult = 0
                        }
//                    }
                } else {
                    boundingBoxOverlay.livenessResult = 2
                    messageString = "Multiple face detected!"
                }
            } else {
                boundingBoxOverlay.livenessResult = 0
            }

            CoroutineScope( Dispatchers.Default ).launch {
                withContext( Dispatchers.Main ) {
                    // Clear the BoundingBoxOverlay and set the new results ( boxes ) to be displayed.
                    boundingBoxOverlay.faceBoundingBoxes = faceResult

                    if(boundingBoxOverlay.livenessResult == 0) {
                        viewBackgroundOfMessage.animate().alpha(0f).start()
                        textViewMessage.animate().alpha(0f).start()
                    } else if(boundingBoxOverlay.livenessResult == 1) {
                        viewBackgroundOfMessage.animate().alpha(0f).start()
                        textViewMessage.animate().alpha(0f).start()
                    } else if(boundingBoxOverlay.livenessResult == 2) {
                        textViewMessage.text = messageString
                        viewBackgroundOfMessage.animate().alpha(1f).start()
                        textViewMessage.animate().alpha(1f).start()
                    }
                    boundingBoxOverlay.invalidate()
                }
            }

            isProcessing = false
            image.close()
        }
    }
}