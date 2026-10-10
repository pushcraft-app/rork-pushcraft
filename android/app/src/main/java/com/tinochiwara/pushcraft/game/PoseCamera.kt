package com.tinochiwara.pushcraft.game

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import java.util.concurrent.Executors

private val landmarkMap = mapOf(
    PoseLandmark.NOSE to Joint.Nose,
    PoseLandmark.LEFT_EYE to Joint.LeftEye,
    PoseLandmark.RIGHT_EYE to Joint.RightEye,
    PoseLandmark.LEFT_EAR to Joint.LeftEar,
    PoseLandmark.RIGHT_EAR to Joint.RightEar,
    PoseLandmark.LEFT_SHOULDER to Joint.LeftShoulder,
    PoseLandmark.RIGHT_SHOULDER to Joint.RightShoulder,
    PoseLandmark.LEFT_ELBOW to Joint.LeftElbow,
    PoseLandmark.RIGHT_ELBOW to Joint.RightElbow,
    PoseLandmark.LEFT_WRIST to Joint.LeftWrist,
    PoseLandmark.RIGHT_WRIST to Joint.RightWrist,
    PoseLandmark.LEFT_HIP to Joint.LeftHip,
    PoseLandmark.RIGHT_HIP to Joint.RightHip,
    PoseLandmark.LEFT_KNEE to Joint.LeftKnee,
    PoseLandmark.RIGHT_KNEE to Joint.RightKnee,
    PoseLandmark.LEFT_ANKLE to Joint.LeftAnkle,
    PoseLandmark.RIGHT_ANKLE to Joint.RightAnkle
)

/** Converts an ML Kit pose into normalized, mirrored joints (+ derived neck and root). */
private fun toFrame(pose: Pose, width: Int, height: Int, mirror: Boolean): PoseFrame {
    val joints = mutableMapOf<Joint, Offset>()
    for ((type, joint) in landmarkMap) {
        val lm = pose.getPoseLandmark(type) ?: continue
        if (lm.inFrameLikelihood < 0.5f) continue
        val x = lm.position.x / width
        val y = lm.position.y / height
        joints[joint] = Offset(if (mirror) 1f - x else x, y)
    }
    val ls = joints[Joint.LeftShoulder]
    val rs = joints[Joint.RightShoulder]
    if (ls != null && rs != null) joints[Joint.Neck] = (ls + rs) / 2f
    val lh = joints[Joint.LeftHip]
    val rh = joints[Joint.RightHip]
    if (lh != null && rh != null) joints[Joint.Root] = (lh + rh) / 2f
    return PoseFrame(joints, Size(width.toFloat(), height.toFloat()))
}

/**
 * Front camera preview with ML Kit pose detection on every frame. Requests
 * camera permission, and reports status (running / denied / no camera).
 */
@OptIn(ExperimentalGetImage::class)
@Composable
fun PoseCameraView(engine: GameEngine, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    var granted by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        granted = ok
        if (!ok) engine.cameraStatus = CameraStatus.Denied
    }
    LaunchedEffect(Unit) {
        if (!granted) launcher.launch(Manifest.permission.CAMERA)
    }
    if (!granted) return

    val executor = remember { Executors.newSingleThreadExecutor() }
    val detector = remember {
        PoseDetection.getClient(PoseDetectorOptions.Builder().setDetectorMode(PoseDetectorOptions.STREAM_MODE).build())
    }
    val providerFuture = remember { ProcessCameraProvider.getInstance(context) }
    DisposableEffect(Unit) {
        onDispose {
            runCatching { providerFuture.get().unbindAll() }
            detector.close()
            executor.shutdown()
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            val previewView = PreviewView(ctx).apply {
                scaleType = PreviewView.ScaleType.FILL_CENTER
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            }
            providerFuture.addListener({
                try {
                    val provider = providerFuture.get()
                    val (selector, isFront) = when {
                        runCatching { provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA) }.getOrDefault(false) ->
                            CameraSelector.DEFAULT_FRONT_CAMERA to true
                        runCatching { provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA) }.getOrDefault(false) ->
                            CameraSelector.DEFAULT_BACK_CAMERA to false
                        else -> {
                            val info = provider.availableCameraInfos.firstOrNull()
                            if (info == null) {
                                engine.cameraStatus = CameraStatus.NoCamera
                                return@addListener
                            }
                            info.cameraSelector to false
                        }
                    }
                    val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                    analysis.setAnalyzer(executor) { proxy ->
                        val media = proxy.image
                        if (media == null) {
                            proxy.close()
                            return@setAnalyzer
                        }
                        val rotation = proxy.imageInfo.rotationDegrees
                        val (w, h) = if (rotation == 90 || rotation == 270) proxy.height to proxy.width else proxy.width to proxy.height
                        detector.process(InputImage.fromMediaImage(media, rotation))
                            .addOnSuccessListener { pose -> engine.handle(toFrame(pose, w, h, isFront)) }
                            .addOnCompleteListener { proxy.close() }
                    }
                    provider.unbindAll()
                    provider.bindToLifecycle(owner, selector, preview, analysis)
                    engine.cameraStatus = CameraStatus.Running
                } catch (e: Exception) {
                    Log.w("PoseCamera", "Camera failed: ${e.message}")
                    engine.cameraStatus = CameraStatus.Failed
                }
            }, ContextCompat.getMainExecutor(ctx))
            previewView
        }
    )
}
