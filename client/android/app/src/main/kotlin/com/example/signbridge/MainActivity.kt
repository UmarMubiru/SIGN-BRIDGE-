package com.example.signbridge

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.database.Cursor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest

private const val WORKSPACE_CHANNEL = "signbridge/workspace_transfer"
private const val PICK_WORKSPACE_TREE = 7314

class MainActivity : FlutterActivity() {
    private var transferResult: MethodChannel.Result? = null
    private var transferMethod: String? = null
    private var transferArguments: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AndroidDatasetAnalysis(this).register(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WORKSPACE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method !in setOf("importWorkspaceTree", "exportWorkspaceTree", "exportDatasetZip")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (transferResult != null) {
                    result.error("TRANSFER_BUSY", "Another workspace transfer is in progress.", null)
                    return@setMethodCallHandler
                }
                transferResult = result
                transferMethod = call.method
                transferArguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                }
                try {
                    startActivityForResult(intent, PICK_WORKSPACE_TREE)
                } catch (error: Exception) {
                    finishTransferError("PICKER_UNAVAILABLE", error.message ?: "The Android folder picker could not be opened.")
                }
            }
    }

    @Deprecated("Deprecated in Android, retained for Flutter's document picker result flow")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_WORKSPACE_TREE) return
        val callback = transferResult ?: return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            transferResult = null
            transferMethod = null
            transferArguments = null
            callback.success(null)
            return
        }
        val tree = data.data!!
        val method = transferMethod
        Thread {
            try {
                val result = when (method) {
                    "importWorkspaceTree" -> importWorkspace(tree)
                    "exportWorkspaceTree" -> exportWorkspace(tree)
                    "exportDatasetZip" -> exportDatasetZip(tree)
                    else -> error("Unknown workspace transfer operation.")
                }
                runOnUiThread {
                    if (transferResult !== callback) return@runOnUiThread
                    transferResult = null
                    transferMethod = null
                    transferArguments = null
                    callback.success(result)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    if (transferResult !== callback) return@runOnUiThread
                    transferResult = null
                    transferMethod = null
                    transferArguments = null
                    callback.error("WORKSPACE_TRANSFER_FAILED", error.message ?: "Workspace transfer failed.", null)
                }
            }
        }.start()
    }

    private fun importWorkspace(tree: Uri): Map<String, Any> {
        val destinationPath = transferArguments?.get("destinationPath") as? String
            ?: error("The internal restore destination is missing.")
        val destination = File(destinationPath)
        require(destination.isDirectory && destination.list()?.isEmpty() == true) {
            "The temporary restore folder is not empty or is unavailable."
        }
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val checksums = mutableMapOf<String, String>()
        copyTreeToLocal(tree, rootId, destination, "", checksums, mutableSetOf(), 0)
        require(File(destination, "workspace.json").isFile) {
            "The selected folder does not contain workspace.json. Choose the workspace folder itself."
        }
        return mapOf("files" to checksums)
    }

    private fun exportWorkspace(tree: Uri): Map<String, Any> {
        val sourcePath = transferArguments?.get("sourcePath") as? String
            ?: error("The verified workspace copy is missing.")
        val suggestedName = transferArguments?.get("folderName") as? String
            ?: "SignBridge_workspace_export"
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val newFolder = DocumentsContract.createDocument(
            contentResolver,
            rootUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            safeName(suggestedName),
        ) ?: error("Could not create the workspace folder in the selected destination.")
        val folderId = DocumentsContract.getDocumentId(newFolder)
        val checksums = mutableMapOf<String, String>()
        try {
            copyLocalToTree(File(sourcePath), tree, folderId, "", checksums)
        } catch (error: Exception) {
            try {
                DocumentsContract.deleteDocument(contentResolver, newFolder)
            } catch (_: Exception) {
                // Leave the partial copy visible if the provider refuses deletion.
            }
            throw error
        }
        return mapOf("folderName" to safeName(suggestedName), "files" to checksums)
    }

    private fun exportDatasetZip(tree: Uri): Map<String, String> {
        val sourcePath = transferArguments?.get("sourcePath") as? String
            ?: error("The dataset archive is missing.")
        val source = File(sourcePath)
        require(source.isFile && source.extension.equals("zip", ignoreCase = true)) {
            "The selected dataset ZIP is unavailable."
        }
        val fileName = safeName(transferArguments?.get("fileName") as? String ?: source.name)
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val target = DocumentsContract.createDocument(
            contentResolver,
            rootUri,
            "application/zip",
            fileName,
        ) ?: error("Could not create the ZIP file in the selected destination.")
        val digest = MessageDigest.getInstance("SHA-256")
        try {
            FileInputStream(source).use { input ->
                contentResolver.openOutputStream(target, "w")?.use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                        digest.update(buffer, 0, count)
                    }
                    output.flush()
                } ?: error("Could not write the dataset ZIP to the selected destination.")
            }
        } catch (error: Exception) {
            try {
                DocumentsContract.deleteDocument(contentResolver, target)
            } catch (_: Exception) {
                // Keep any partial file visible if the provider refuses deletion.
            }
            throw error
        }
        return mapOf("fileName" to fileName, "sha256" to digest.digest().toHex())
    }

    private fun copyTreeToLocal(
        tree: Uri,
        parentId: String,
        destination: File,
        relative: String,
        checksums: MutableMap<String, String>,
        visited: MutableSet<String>,
        depth: Int,
    ) {
        require(depth <= 64) { "The selected workspace folder is nested too deeply." }
        require(visited.add(parentId)) { "The selected folder contains a directory cycle." }
        forEachChild(tree, parentId) { childId, name, mime ->
            val cleanName = safeName(name)
            val childRelative = if (relative.isEmpty()) cleanName else "$relative/$cleanName"
            val output = File(destination, childRelative)
            require(output.canonicalPath.startsWith(destination.canonicalPath + File.separator)) {
                "The selected workspace contains an invalid file path."
            }
            val childUri = DocumentsContract.buildDocumentUriUsingTree(tree, childId)
            if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                require(output.mkdirs() || output.isDirectory) { "Could not create $childRelative in the restored copy." }
                copyTreeToLocal(tree, childId, destination, childRelative, checksums, visited, depth + 1)
            } else {
                val input = contentResolver.openInputStream(childUri)
                    ?: error("Could not read $childRelative from the selected folder.")
                val digest = MessageDigest.getInstance("SHA-256")
                output.parentFile?.mkdirs()
                input.use { source ->
                    FileOutputStream(output).use { target ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val count = source.read(buffer)
                            if (count < 0) break
                            target.write(buffer, 0, count)
                            digest.update(buffer, 0, count)
                        }
                        target.fd.sync()
                    }
                }
                checksums[childRelative] = digest.digest().toHex()
            }
        }
    }

    private fun copyLocalToTree(
        source: File,
        tree: Uri,
        parentId: String,
        relative: String,
        checksums: MutableMap<String, String>,
    ) {
        val children = source.listFiles() ?: error("Could not read the verified workspace copy.")
        for (child in children) {
            val name = safeName(child.name)
            val childRelative = if (relative.isEmpty()) name else "$relative/$name"
            if (child.isDirectory) {
                val parentUri = DocumentsContract.buildDocumentUriUsingTree(tree, parentId)
                val created = DocumentsContract.createDocument(
                    contentResolver,
                    parentUri,
                    DocumentsContract.Document.MIME_TYPE_DIR,
                    name,
                ) ?: error("Could not create folder $childRelative in the selected destination.")
                copyLocalToTree(child, tree, DocumentsContract.getDocumentId(created), childRelative, checksums)
            } else if (child.isFile) {
                val parentUri = DocumentsContract.buildDocumentUriUsingTree(tree, parentId)
                val created = DocumentsContract.createDocument(
                    contentResolver,
                    parentUri,
                    mimeType(child.name),
                    name,
                ) ?: error("Could not create file $childRelative in the selected destination.")
                val digest = MessageDigest.getInstance("SHA-256")
                FileInputStream(child).use { sourceStream ->
                    contentResolver.openOutputStream(created, "w")?.use { target ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val count = sourceStream.read(buffer)
                            if (count < 0) break
                            target.write(buffer, 0, count)
                            digest.update(buffer, 0, count)
                        }
                        target.flush()
                    } ?: error("Could not write file $childRelative to the selected destination.")
                }
                checksums[childRelative] = digest.digest().toHex()
            }
        }
    }

    private fun forEachChild(
        tree: Uri,
        parentId: String,
        action: (String, String, String) -> Unit,
    ) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        val cursor: Cursor = contentResolver.query(childrenUri, columns, null, null, null)
            ?: error("Could not list files in the selected folder.")
        cursor.use {
            val idColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (it.moveToNext()) {
                action(it.getString(idColumn), it.getString(nameColumn), it.getString(mimeColumn))
            }
        }
    }

    private fun safeName(value: String): String {
        require(value.isNotBlank() && value != "." && value != ".." &&
            !value.contains('/') && !value.contains('\\') && !value.contains('\u0000')) {
            "The workspace contains an invalid file or folder name."
        }
        return value
    }

    private fun mimeType(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "json" -> "application/json"
        "csv" -> "text/csv"
        "txt" -> "text/plain"
        "jpg", "jpeg" -> "image/jpeg"
        "mp4" -> "video/mp4"
        "zip" -> "application/zip"
        else -> "application/octet-stream"
    }

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it.toInt() and 0xff) }

    private fun finishTransferError(code: String, message: String) {
        transferResult?.error(code, message, null)
        transferResult = null
        transferMethod = null
        transferArguments = null
    }
}
