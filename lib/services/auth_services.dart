import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/services/firestore_services.dart';

class AuthServices {
  final _auth = FirebaseAuth.instance;

  final firestoreServices = FirestoreServices();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String get uid => _auth.currentUser!.uid;

  bool checkLogin() {
    // print(_auth.currentUser);
    if (_auth.currentUser != null) {
      return true;
    }
    return false;
  }

  Future<void> sendOTP({
    required String phoneNumber,
    required Function() onLoginSuccess,
    required Function(String verId) onOtpSent,
    required Function(FirebaseAuthException) onLoginFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          await firestoreServices.createUserInFireStore(_auth.currentUser);
          onLoginSuccess();
        } on FirebaseAuthException catch (e) {
          // print("Some error occured Mac");
          onLoginFailed(e);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onLoginFailed(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        onOtpSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verId) {
        onOtpSent(verId);
      },
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

  Future<void> saveUserInfo({
    required String name,
    required String avatar,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user Logged in");

    await firestoreServices.updateUserInfo(
      user: user,
      userName: name,
      avatar: avatar,
    );
  }

  Future<void> signOut() async {
    _auth.signOut();
  }
}
