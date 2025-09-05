import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/services/firestore_services.dart';

class AuthServices {
  final _auth = FirebaseAuth.instance;

  final firestoreServices = FirestoreServices();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String get uid => _auth.currentUser!.uid;
  String verificationId = "";

  bool checkLogin() {
    // print(_auth.currentUser);
    if (_auth.currentUser != null) {
      return true;
    }
    return false;
  }

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> verifyOTP({
    required String otp,
    required verificationId,
  }) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    firestoreServices.createUserInFireStore(userCredential.user);
    return userCredential;
  }

  // void _isUserProfileComplete() async {
  //   final user = _auth.currentUser;
  //   final doc = await _fireStore.collection('users').doc(user!.uid).get();
  //   final data = doc.data();
  // }

  Future<void> signOut() async {
    _auth.signOut();
  }
}
