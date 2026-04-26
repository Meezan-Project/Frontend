import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/theme/app_colors.dart';

enum CardNetwork { visa, mastercard, meeza, unknown }

class SavedPaymentCard {
  final String cardNumber;
  final String holderName;
  final String expiry;
  final String cvv;
  final CardNetwork network;
  final bool isDefault;

  const SavedPaymentCard({
    required this.cardNumber,
    required this.holderName,
    required this.expiry,
    required this.cvv,
    required this.network,
    this.isDefault = false,
  });

  String get maskedNumber {
    final last4 = cardNumber.length >= 4
        ? cardNumber.substring(cardNumber.length - 4)
        : cardNumber;
    return '**** **** **** $last4';
  }

  SavedPaymentCard copyWith({
    String? cardNumber,
    String? holderName,
    String? expiry,
    String? cvv,
    CardNetwork? network,
    bool? isDefault,
  }) {
    return SavedPaymentCard(
      cardNumber: cardNumber ?? this.cardNumber,
      holderName: holderName ?? this.holderName,
      expiry: expiry ?? this.expiry,
      cvv: cvv ?? this.cvv,
      network: network ?? this.network,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cardNumber': _digitsOnly(cardNumber),
      'holderName': holderName.trim(),
      'expiry': expiry.trim(),
      'cvv': _digitsOnly(cvv),
      'network': network.name,
      'isDefault': isDefault,
    };
  }

  factory SavedPaymentCard.fromMap(Map<String, dynamic> data) {
    final rawNumber = data['cardNumber']?.toString() ?? '';
    final rawHolder = data['holderName']?.toString() ?? '';
    final rawExpiry = data['expiry']?.toString() ?? '';
    final rawCvv = data['cvv']?.toString() ?? '';
    final rawNetwork = data['network']?.toString() ?? '';

    return SavedPaymentCard(
      cardNumber: _digitsOnly(rawNumber),
      holderName: rawHolder,
      expiry: rawExpiry,
      cvv: _digitsOnly(rawCvv),
      network: CardNetwork.values.where((n) => n.name == rawNetwork).isNotEmpty
          ? CardNetwork.values.firstWhere((n) => n.name == rawNetwork)
          : _detectNetwork(rawNumber),
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }
}

class CardEditorResult {
  final SavedPaymentCard? updatedCard;
  final bool deleted;

  const CardEditorResult._({this.updatedCard, required this.deleted});

  const CardEditorResult.updated(SavedPaymentCard card)
    : this._(updatedCard: card, deleted: false);

  const CardEditorResult.deleted() : this._(updatedCard: null, deleted: true);
}

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  final List<SavedPaymentCard> _cards = <SavedPaymentCard>[];

  User? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadCards();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFB3261E)
                    : const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 36.sp,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadCards() async {
    final user = _currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showMessage('Please sign in again', isError: true);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data() ?? <String, dynamic>{};
      final rawCards = data['savedCards'];
      final parsedCards = <SavedPaymentCard>[];

      if (rawCards is List) {
        for (final raw in rawCards) {
          if (raw is Map) {
            parsedCards.add(
              SavedPaymentCard.fromMap(Map<String, dynamic>.from(raw)),
            );
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _cards
          ..clear()
          ..addAll(parsedCards);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('Failed to load saved cards: $error', isError: true);
    }
  }

  Future<void> _persistCards(
    List<SavedPaymentCard> cards, {
    String? successMessage,
  }) async {
    final user = _currentUser;
    if (user == null) {
      _showMessage('Please sign in again', isError: true);
      return;
    }

    if (mounted) {
      setState(() => _isSaving = true);
    }

    final payload = cards.map((card) => card.toMap()).toList();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'savedCards': payload,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final verification = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final rawCards = verification.data()?['savedCards'];
      final savedCount = rawCards is List ? rawCards.length : 0;
      if (savedCount != cards.length) {
        throw Exception('Could not verify card save.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _cards
          ..clear()
          ..addAll(cards);
      });

      if (successMessage != null && successMessage.isNotEmpty) {
        _showMessage(successMessage);
      }
    } catch (error) {
      _showMessage('Failed to save cards: $error', isError: true);
      await _loadCards();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _setDefaultCard(int index) async {
    if (_cards[index].isDefault) return;

    final updatedCards = _cards.asMap().entries.map((entry) {
      return entry.value.copyWith(isDefault: entry.key == index);
    }).toList();

    await _persistCards(
      updatedCards,
      successMessage: 'Default payment method updated',
    );
  }

  Future<void> _openAddCard() async {
    final result = await Navigator.of(context).push<CardEditorResult?>(
      MaterialPageRoute(builder: (_) => const AddNewCardScreen()),
    );

    if (!mounted || result == null || result.updatedCard == null) {
      return;
    }

    final newCard = result.updatedCard!.copyWith(isDefault: _cards.isEmpty);
    final updatedCards = <SavedPaymentCard>[newCard, ..._cards];
    await _persistCards(
      updatedCards,
      successMessage: 'Card added successfully',
    );
  }

  Future<void> _openEditCard(int index) async {
    final result = await Navigator.of(context).push<CardEditorResult?>(
      MaterialPageRoute(
        builder: (_) => AddNewCardScreen(initialCard: _cards[index]),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.deleted) {
      final wasDefault = _cards[index].isDefault;
      final updatedCards = List<SavedPaymentCard>.from(_cards)..removeAt(index);

      if (wasDefault && updatedCards.isNotEmpty) {
        updatedCards[0] = updatedCards[0].copyWith(isDefault: true);
      }

      await _persistCards(
        updatedCards,
        successMessage: 'Card deleted successfully',
      );
      return;
    }

    if (result.updatedCard != null) {
      final updatedCards = List<SavedPaymentCard>.from(_cards)
        ..[index] = result.updatedCard!;
      await _persistCards(
        updatedCards,
        successMessage: 'Card updated successfully',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1726)
          : const Color(0xFFF4F7FB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: _PremiumHeader(
                  title: 'Saved Cards',
                  subtitle: 'Securely manage your payment methods',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
                child: SizedBox(
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _openAddCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22.r),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      'Add New Card',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.sp,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SizedBox(
                    width: 28.w,
                    height: 28.h,
                    child: const CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else if (_cards.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No saved cards yet',
                    style: GoogleFonts.cairo(
                      color: isDark ? Colors.white70 : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                sliver: SliverList.separated(
                  itemCount: _cards.length,
                  separatorBuilder: (_, _) => SizedBox(height: 14.h),
                  itemBuilder: (_, index) {
                    final card = _cards[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 8.h, left: 4.w),
                          child: GestureDetector(
                            onTap: () => _setDefaultCard(index),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: Checkbox(
                                    value: card.isDefault,
                                    onChanged: (value) {
                                      if (value == true) {
                                        _setDefaultCard(index);
                                      }
                                    },
                                    activeColor: AppColors.navyBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white54
                                          : AppColors.navyBlue.withValues(
                                              alpha: 0.5,
                                            ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  card.isDefault
                                      ? 'Default Payment Method'
                                      : 'Set as Default',
                                  style: GoogleFonts.cairo(
                                    color: card.isDefault
                                        ? (isDark
                                              ? Colors.white
                                              : AppColors.navyBlue)
                                        : (isDark
                                              ? Colors.white54
                                              : AppColors.textDark.withValues(
                                                  alpha: 0.6,
                                                )),
                                    fontWeight: card.isDefault
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openEditCard(index),
                          child: _CardFace(
                            cardNumber: card.maskedNumber,
                            expiry: card.expiry,
                            holderName: card.holderName,
                            cvv: card.cvv,
                            network: card.network,
                            showBack: false,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AddNewCardScreen extends StatefulWidget {
  final SavedPaymentCard? initialCard;

  const AddNewCardScreen({super.key, this.initialCard});

  @override
  State<AddNewCardScreen> createState() => _AddNewCardScreenState();
}

class _AddNewCardScreenState extends State<AddNewCardScreen>
    with SingleTickerProviderStateMixin {
  final _numberController = TextEditingController();
  final _holderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cvvFocusNode = FocusNode();

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  bool get _isEditMode => widget.initialCard != null;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    );

    _numberController.addListener(_refresh);
    _holderController.addListener(_refresh);
    _expiryController.addListener(_refresh);
    _cvvController.addListener(_refresh);

    final initialCard = widget.initialCard;
    if (initialCard != null) {
      _numberController.text = _formatCardNumber(initialCard.cardNumber);
      _holderController.text = initialCard.holderName;
      _expiryController.text = initialCard.expiry;
      _cvvController.text = initialCard.cvv;
    }

    _cvvFocusNode.addListener(() {
      if (_cvvFocusNode.hasFocus) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
      _refresh();
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _holderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cvvFocusNode.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  CardNetwork get _network => _detectNetwork(_numberController.text);

  bool get _isFormValid {
    final rawNumber = _digitsOnly(_numberController.text);
    final rawCvv = _digitsOnly(_cvvController.text);
    final holder = _holderController.text.trim();
    final expiry = _expiryController.text.trim();

    return rawNumber.length == 16 &&
        _isValidExpiry(expiry) &&
        rawCvv.length == 3 &&
        holder.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_isFormValid) {
      return;
    }

    final card = SavedPaymentCard(
      cardNumber: _digitsOnly(_numberController.text),
      holderName: _holderController.text.trim().toUpperCase(),
      expiry: _expiryController.text.trim(),
      cvv: _digitsOnly(_cvvController.text),
      network: _network,
      isDefault: widget.initialCard?.isDefault ?? false,
    );

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(CardEditorResult.updated(card));
  }

  Future<void> _confirmDeleteCard() async {
    if (!_isEditMode) {
      return;
    }

    final shouldDelete =
        await showDialog<bool?>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Card'),
              content: const Text('Are you sure you want to delete it?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('No'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !mounted) {
      return;
    }

    Navigator.of(context).pop(const CardEditorResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1726)
          : const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
              child: _PremiumHeader(
                title: _isEditMode ? 'Edit Card' : 'Add New Card',
                subtitle: _isEditMode
                    ? 'Update card details or delete this card'
                    : 'Enter your card details securely',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (_, _) {
                  final angle = _flipAnimation.value * math.pi;
                  final showBack = angle > math.pi / 2;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: _CardFace(
                      cardNumber: _formatCardNumber(_numberController.text),
                      expiry: _expiryController.text,
                      holderName: _holderController.text,
                      network: _network,
                      cvv: _cvvController.text,
                      showBack: showBack,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 14.h),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2438) : Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22.r),
                  ),
                ),
                child: ListView(
                  children: [
                    _CardTextField(
                      controller: _numberController,
                      label: 'Card Number',
                      hint: '1234 5678 9012 3456',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(19),
                        _CardNumberInputFormatter(),
                      ],
                      suffix: _CardNetworkBadge(network: _network),
                    ),
                    SizedBox(height: 12.h),
                    _CardTextField(
                      controller: _expiryController,
                      label: 'Expiry Date',
                      hint: 'MM/YY',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(5),
                        _ExpiryInputFormatter(),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    _CardTextField(
                      controller: _holderController,
                      label: 'Card Holder Name',
                      hint: 'Full name',
                      keyboardType: TextInputType.name,
                    ),
                    SizedBox(height: 12.h),
                    _CardTextField(
                      controller: _cvvController,
                      label: 'CVV',
                      hint: '123',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(3),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      focusNode: _cvvFocusNode,
                    ),
                    SizedBox(height: 20.h),
                    if (_isEditMode)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: SizedBox(
                          height: 50.h,
                          child: OutlinedButton.icon(
                            onPressed: _confirmDeleteCard,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFC62828)),
                              foregroundColor: const Color(0xFFC62828),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text(
                              'Delete Card',
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: _isFormValid ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFormValid
                              ? AppColors.legalGold
                              : (isDark
                                    ? const Color(0xFF41516B)
                                    : const Color(0xFFB8C4D7)),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isEditMode ? 'Save Changes' : 'Add Card',
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final String cardNumber;
  final String expiry;
  final String holderName;
  final String cvv;
  final CardNetwork network;
  final bool showBack;

  const _CardFace({
    required this.cardNumber,
    required this.expiry,
    required this.holderName,
    required this.cvv,
    required this.network,
    required this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 1.58,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: LinearGradient(
            colors: _gradientFor(network, isDark),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: Offset(0, 12.h),
            ),
          ],
        ),
        child: showBack
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(math.pi),
                child: _CardBackContent(cvv: cvv),
              )
            : _CardFrontContent(
                cardNumber: cardNumber,
                expiry: expiry,
                holderName: holderName,
                network: network,
              ),
      ),
    );
  }

  List<Color> _gradientFor(CardNetwork network, bool isDark) {
    switch (network) {
      case CardNetwork.visa:
        return [const Color(0xFF0A2E63), const Color(0xFF2364D2)];
      case CardNetwork.mastercard:
        return [const Color(0xFF3D1A56), const Color(0xFFB0413E)];
      case CardNetwork.meeza:
        return [const Color(0xFF0B5E55), const Color(0xFFC08B27)];
      case CardNetwork.unknown:
        return isDark
            ? [const Color(0xFF2A3550), const Color(0xFF41516B)]
            : [const Color(0xFF173F73), const Color(0xFF0B5E55)];
    }
  }
}

class _CardFrontContent extends StatelessWidget {
  final String cardNumber;
  final String expiry;
  final String holderName;
  final CardNetwork network;

  const _CardFrontContent({
    required this.cardNumber,
    required this.expiry,
    required this.holderName,
    required this.network,
  });

  @override
  Widget build(BuildContext context) {
    final numberText = cardNumber.trim().isEmpty
        ? '**** **** **** ****'
        : cardNumber;
    final expiryText = expiry.trim().isEmpty ? 'MM/YY' : expiry;
    final holderText = holderName.trim().isEmpty
        ? 'CARD HOLDER'
        : holderName.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42.w,
              height: 30.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            const Spacer(),
            _CardNetworkBadge(network: network, bright: true),
          ],
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Text(
            _formatCardNumber(numberText),
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _CardMetaItem(label: 'Card Holder', value: holderText),
            ),
            SizedBox(width: 16.w),
            _CardMetaItem(label: 'Expiry', value: expiryText),
          ],
        ),
      ],
    );
  }
}

class _CardBackContent extends StatelessWidget {
  final String cvv;

  const _CardBackContent({required this.cvv});

  @override
  Widget build(BuildContext context) {
    final cvvText = cvv.trim().isEmpty ? '***' : cvv;

    return Column(
      children: [
        SizedBox(height: 16.h),
        Container(
          width: double.infinity,
          height: 44.h,
          color: Colors.black.withValues(alpha: 0.7),
        ),
        SizedBox(height: 16.h),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 130.w,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              cvvText,
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(
                color: AppColors.textDark,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            'Secure card • Mezaan',
            style: GoogleFonts.cairo(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
              fontSize: 11.sp,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardMetaItem extends StatelessWidget {
  final String label;
  final String value;

  const _CardMetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CardTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final FocusNode? focusNode;

  const _CardTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.inputFormatters,
    this.suffix,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: suffix,
              ),
        suffixIconConstraints: BoxConstraints(minWidth: 58.w, minHeight: 34.h),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2A40) : const Color(0xFFF8FAFD),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334866) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: AppColors.legalGold, width: 1.8),
        ),
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _PremiumHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF042A52), Color(0xFF0B5E55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2345).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20.sp,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNetworkBadge extends StatelessWidget {
  final CardNetwork network;
  final bool bright;

  const _CardNetworkBadge({required this.network, this.bright = false});

  @override
  Widget build(BuildContext context) {
    final border = bright
        ? Colors.white.withValues(alpha: 0.32)
        : const Color(0xFFCFD8E8);
    final bg = bright
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFF2F6FD);
    final textColor = bright ? Colors.white : AppColors.navyBlue;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: border),
      ),
      child: Text(
        _label(network),
        style: GoogleFonts.cairo(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 11.sp,
        ),
      ),
    );
  }

  String _label(CardNetwork network) {
    switch (network) {
      case CardNetwork.visa:
        return 'VISA';
      case CardNetwork.mastercard:
        return 'Mastercard';
      case CardNetwork.meeza:
        return 'Meeza';
      case CardNetwork.unknown:
        return 'Card';
    }
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digitsOnly(newValue.text);
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 4; i++) {
      buffer.write(digits[i]);
      if (i == 1 && i != digits.length - 1) {
        buffer.write('/');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

CardNetwork _detectNetwork(String input) {
  final digits = _digitsOnly(input);

  if (digits.startsWith('5078') || digits.startsWith('9739')) {
    return CardNetwork.meeza;
  }
  if (digits.startsWith('4')) {
    return CardNetwork.visa;
  }
  if (digits.startsWith('5')) {
    return CardNetwork.mastercard;
  }
  return CardNetwork.unknown;
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String _formatCardNumber(String input) {
  if (input.contains('*')) {
    return input;
  }

  final digits = _digitsOnly(input);
  if (digits.isEmpty) {
    return '**** **** **** ****';
  }

  final chunks = <String>[];
  for (var i = 0; i < digits.length; i += 4) {
    final end = (i + 4 < digits.length) ? i + 4 : digits.length;
    chunks.add(digits.substring(i, end));
  }
  return chunks.join(' ');
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digitsOnly(newValue.text);
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 16; i++) {
      buffer.write(digits[i]);
      if ((i + 1) % 4 == 0 && i != digits.length - 1) {
        buffer.write(' ');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

bool _isValidExpiry(String expiry) {
  final match = RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').firstMatch(expiry);
  if (match == null) {
    return false;
  }

  final month = int.parse(match.group(1)!);
  final yearPart = int.parse(match.group(2)!);
  final now = DateTime.now();
  final currentYearPart = now.year % 100;

  if (yearPart < currentYearPart) {
    return false;
  }

  if (yearPart == currentYearPart && month < now.month) {
    return false;
  }

  return true;
}
