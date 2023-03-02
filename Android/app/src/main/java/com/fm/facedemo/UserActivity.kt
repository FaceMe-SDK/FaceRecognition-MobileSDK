package com.fm.facedemo

import android.content.DialogInterface
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Rect
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.text.TextUtils
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.*
import androidx.appcompat.app.AlertDialog
import com.fm.face.*
import com.google.android.material.floatingactionbutton.FloatingActionButton

class UserActivity : AppCompatActivity() {

    companion object {
        private val TAG = UserActivity::class.simpleName
        private val ADD_USER_REQUEST_CODE = 1
        private val CAMERA_REQUEST_CODE = 2
    }

    private lateinit var userDb: UserDB
    private lateinit var adapter: UsersAdapter
    private lateinit var txtWarning: TextView
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_user)

        userDb = UserDB(this)
        userDb.loadUsers()

        adapter = UsersAdapter(this, UserDB.userInfos)
        val listView: ListView = findViewById<View>(R.id.userList) as ListView
        listView.setAdapter(adapter)

        listView.setOnItemClickListener { adapterView, view, i, l ->
            val alertDialog: AlertDialog.Builder = AlertDialog.Builder(this@UserActivity)
            alertDialog.setTitle(getString(R.string.delete_user))
            val items = arrayOf(getString(R.string.delete), getString(R.string.delete_all))
            alertDialog.setSingleChoiceItems(items, -1,
                DialogInterface.OnClickListener { dialog, which ->
                    when (which) {
                        0 -> {

                            userDb.deleteUser(UserDB.userInfos.get(i).userName)
                            UserDB.userInfos.removeAt(i)

                            adapter.notifyDataSetChanged()
                            dialog.cancel()
                        }
                        1 -> {
                            userDb.deleteAllUser()
                            UserDB.userInfos.clear()
                            adapter.notifyDataSetChanged()
                            dialog.cancel()
                        }
                    }
                })

            val alert: AlertDialog = alertDialog.create()
            alert.show()
        }

        findViewById<FloatingActionButton>(R.id.buttonAdd).setOnClickListener {
            val intent = Intent()
            intent.setType("image/*")
            intent.setAction(Intent.ACTION_PICK)
            startActivityForResult(Intent.createChooser(intent, getString(R.string.select_picture)), ADD_USER_REQUEST_CODE)
        }

        findViewById<FloatingActionButton>(R.id.buttonCamera).setOnClickListener {
            startActivityForResult(Intent(this, CameraActivity::class.java), CAMERA_REQUEST_CODE)
        }

        txtWarning = findViewById<TextView>(R.id.txtWarning)

        FaceSDK.createInstance(this)
        val ret = FaceSDK.getInstance().init(assets)
        if(ret != FaceSDK.SDK_SUCCESS) {
            txtWarning.visibility = View.VISIBLE
            if(ret == FaceSDK.SDK_ACTIVATE_APPID_ERROR) {
                txtWarning.text = getString(R.string.appid_error)
            } else if(ret == FaceSDK.SDK_ACTIVATE_INVALID_LICENSE) {
                txtWarning.text = getString(R.string.invalid_license)
            } else if(ret == FaceSDK.SDK_ACTIVATE_LICENSE_EXPIRED) {
                txtWarning.text = getString(R.string.license_expired)
            } else if(ret == FaceSDK.SDK_NO_ACTIVATED) {
                txtWarning.text = getString(R.string.no_activated)
            } else if(ret == FaceSDK.SDK_INIT_ERROR) {
                txtWarning.text = getString(R.string.init_error)
            }
        }
    }
    override fun onResume() {
        super.onResume()

        adapter.notifyDataSetChanged()
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == ADD_USER_REQUEST_CODE && resultCode == RESULT_OK) {
            try {
                var bitmap: Bitmap = ImageRotator.getCorrectlyOrientedImage(this, data?.data!!)
                var faceResults: List<FaceBox>? = FaceSDK.getInstance().detectFace(bitmap)
                if(faceResults.isNullOrEmpty()) {
                    Toast.makeText(this, getString(R.string.no_face_detected), Toast.LENGTH_SHORT).show()
                } else if(faceResults.size == 1) {
                    val livenessScore = FaceSDK.getInstance().checkLiveness(bitmap, faceResults!!.get(0))
                    if(livenessScore > FrameAnalyser.LIVENESS_THRESHOLD) {
                        val faceRect = Rect(faceResults!!.get(0).left, faceResults!!.get(0).top, faceResults!!.get(0).right, faceResults!!.get(0).bottom)
                        val cropRect = Utils.getBestRect(bitmap.width, bitmap.height, faceRect)
                        val faceImage = Utils.crop(bitmap, cropRect.left, cropRect.top, cropRect.width(), cropRect.height(), 120, 120)
                        val featData = FaceSDK.getInstance().extractFeature(bitmap, faceResults!!.get(0))

                        val userName = String.format("User%03d", userDb.getLastUserId() + 1)

                        val inputView = LayoutInflater.from(this)
                            .inflate(R.layout.dialog_input_view, null, false)
                        val editText = inputView.findViewById<EditText>(R.id.et_user_name)
                        val ivHead = inputView.findViewById<ImageView>(R.id.iv_head)
                        ivHead.setImageBitmap(faceImage)
                        editText.setText(userName)
                        val confirmUpdateDialog: AlertDialog = AlertDialog.Builder(this)
                            .setView(inputView)
                            .setPositiveButton(
                                "OK", null
                            )
                            .setNegativeButton(
                                "Cancel", null
                            )
                            .create()
                        confirmUpdateDialog.show()
                        confirmUpdateDialog.getButton(AlertDialog.BUTTON_POSITIVE)
                            .setOnClickListener { v: View? ->
                                val s = editText.text.toString()
                                if (TextUtils.isEmpty(s)) {
                                    editText.error = application.getString(R.string.name_should_not_be_empty)
                                    return@setOnClickListener
                                }

                                var exists:Boolean = false
                                for(user in UserDB.userInfos) {
                                    if(TextUtils.equals(user.userName, s)) {
                                        exists = true
                                        break
                                    }
                                }

                                if(exists) {
                                    editText.error = application.getString(R.string.duplicated_name)
                                    return@setOnClickListener
                                }

                                val userId = userDb.insertUser(s, faceImage, featData)
                                val face = UserInfo(userId, s, faceImage, featData)
                                UserDB.userInfos.add(face)

                                confirmUpdateDialog.cancel()

                                adapter.notifyDataSetChanged()
                                Toast.makeText(this, getString(R.string.register_successed), Toast.LENGTH_SHORT).show()
                            }
                    } else {
                        Toast.makeText(this, getString(R.string.liveness_check_failed), Toast.LENGTH_SHORT).show()
                    }

                } else if (faceResults.size > 1) {
                    Toast.makeText(this, getString(R.string.multiple_face_detected), Toast.LENGTH_SHORT).show()
                }
            } catch (e: java.lang.Exception) {
                //handle exception
                e.printStackTrace()
            }
        }
    }
}