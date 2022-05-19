import 'package:deep_pick/deep_pick.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'package:flutterwave_standard/core/TransactionCallBack.dart';
import 'package:flutterwave_standard/core/navigation_controller.dart';
import 'package:flutterwave_standard/models/requests/standard_request.dart';
import 'package:flutterwave_standard/models/responses/charge_response.dart';
import 'package:flutterwave_standard/view/view_utils.dart';

import 'flutterwave_style.dart';

class PaymentWidget extends StatefulWidget {
  final FlutterwaveStyle style;
  final StandardRequest request;
  final BuildContext mainContext;

  BuildContext? loadingDialogContext;
  SnackBar? snackBar;

  PaymentWidget({
    Key? key,
    required this.style,
    required this.request,
    required this.mainContext,
    this.loadingDialogContext,
    this.snackBar,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PaymentState();
}

class _PaymentState extends State<PaymentWidget> implements TransactionCallBack {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _formKey = GlobalKey<FormState>();
  bool _isDisabled = false;
  late NavigationController controller;
  var currencyController = TextEditingController();
  String selectedCurrency = "";
  String _currentAmount = '0.00';

  var amount = '';

  @override
  void initState() {
    _isDisabled = false;
    amount = widget.request.amount;
    selectedCurrency = widget.request.currency!;
    widget.request.currencies.putIfAbsent('USD', () => 1);
    currencyController = TextEditingController(text: '');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    controller = NavigationController(Client(), widget.style, this);
    if (widget.request.currencies.keys.length == 1) {
      _currentAmount = (pick(amount).asDoubleOrThrow() * 1).toStringAsFixed(2);
    } else {
      if (widget.request.currency!.contains('USD') && selectedCurrency == 'USD') {
        _currentAmount = (pick(amount).asDoubleOrThrow() * pick(widget.request.currencies[selectedCurrency]).asDoubleOrThrow()).toStringAsFixed(2);
      } else if (widget.request.currency == selectedCurrency) {
        _currentAmount = (pick(amount).asDoubleOrThrow() * 1).toStringAsFixed(2);
      } else if (widget.request.currency!.contains('USD') && selectedCurrency != 'USD') {
        _currentAmount = (pick(amount).asDoubleOrThrow() * pick(widget.request.currencies[selectedCurrency]).asDoubleOrThrow()).toStringAsFixed(2);
      } else if (!widget.request.currency!.contains('USD') && selectedCurrency == 'USD') {
        _currentAmount = (pick(amount).asDoubleOrThrow() / pick(widget.request.currencies[widget.request.currency]).asDoubleOrThrow()).toStringAsFixed(2);
      } else if (!widget.request.currency!.contains('USD') && selectedCurrency != 'USD') {
        _currentAmount = ((pick(amount).asDoubleOrThrow() / pick(widget.request.currencies[widget.request.currency]).asDoubleOrThrow()) *
                pick(widget.request.currencies[selectedCurrency]).asDoubleOrThrow())
            .toStringAsFixed(2);
      }
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: widget.request.isTestMode,
      home: Scaffold(
        backgroundColor: widget.style.getMainBackgroundColor(),
        appBar: FlutterwaveViewUtils.appBar(
          context,
          widget.style.getAppBarText(),
          widget.style.getAppBarTextStyle(),
          widget.style.getAppBarIcon(),
          widget.style.getAppBarColor(),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (widget.request.currencies.keys.length > 1)
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 50, 20, 0),
                    child: Text.rich(
                      TextSpan(
                        text: 'The original charge amount (',
                        style: Theme.of(context).textTheme.caption,
                        children: [
                          TextSpan(
                            text: '${widget.request.currency} $amount',
                            style: widget.style.getButtonTextStyle().copyWith(fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: ') for this transaction (fees exclusive) has been converted to your preferred currency for payment. You will be charged ',
                                style: Theme.of(context).textTheme.caption,
                                children: [
                                  TextSpan(
                                    text: '$selectedCurrency $_currentAmount',
                                    style: widget.style.getButtonTextStyle().copyWith(fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                        text: ' at a rate of ',
                                        style: Theme.of(context).textTheme.caption,
                                        children: [
                                          TextSpan(
                                            text: '$selectedCurrency ${pick(widget.request.currencies[selectedCurrency]).asDoubleOrThrow()}',
                                            style: widget.style.getButtonTextStyle().copyWith(fontWeight: FontWeight.bold),
                                            children: [
                                              TextSpan(
                                                text: ' to ',
                                                style: Theme.of(context).textTheme.caption,
                                                children: [
                                                  TextSpan(
                                                    text: '${widget.request.currency} ${widget.request.currencies[widget.request.currency]}',
                                                    style: widget.style.getButtonTextStyle().copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.request.currencies.keys.length > 1)
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 50, 20, 0),
                    child: TextFormField(
                      controller: this.currencyController,
                      textInputAction: TextInputAction.next,
                      style: widget.style.getButtonTextStyle(),
                      readOnly: true,
                      onTap: this._openBottomSheet,
                      decoration: InputDecoration(
                        hintText: "Select Preferred Currency",
                      ),
                      validator: (value) => value!.isNotEmpty ? null : "Please select a currency to proceed",
                    ),
                  ),
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: EdgeInsets.fromLTRB(20, 50, 20, 0),
                  child: ElevatedButton(
                    autofocus: true,
                    onPressed: _handleButtonClicked,
                    style: ElevatedButton.styleFrom(primary: widget.style.getButtonColor(), textStyle: widget.style.getButtonTextStyle()),
                    child: Text(
                      '${widget.style.getButtonText()} $selectedCurrency $_currentAmount',
                      style: widget.style.getButtonTextStyle(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openBottomSheet() {
    showModalBottomSheet(
      context: this.context,
      builder: (context) {
        return this._getCurrency();
      },
    );
  }

  Widget _getCurrency() {
    final currencies = widget.request.currencies.keys.toList();
    return Container(
      height: 250,
      margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
      color: Colors.white,
      child: ListView(
        children: currencies
            .map(
              (currency) => ListTile(
                onTap: () => {this._handleCurrencyTap(currency)},
                title: Column(
                  children: [
                    Text(
                      currency,
                      textAlign: TextAlign.start,
                      style: widget.style.getButtonTextStyle(),
                    ),
                    SizedBox(height: 4),
                    Divider(height: 1)
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  _handleCurrencyTap(String currency) {
    this.setState(() {
      this.selectedCurrency = currency;
      this.currencyController.text = currency;
    });
    Navigator.pop(this.context);
  }

  void _handleButtonClicked() {
    if (_isDisabled) return;
    if (_formKey.currentState!.validate()) {
      _showConfirmDialog();
    }
  }

  void _handlePayment() async {
    try {
      Navigator.of(widget.mainContext).pop(); // to remove confirmation dialog
      _toggleButtonActive(false);
      widget.request.amount = _currentAmount;
      widget.request.currency = this.selectedCurrency;
      controller.startTransaction(widget.request);
      _toggleButtonActive(true);
    } catch (error) {
      _toggleButtonActive(true);
      _showErrorAndClose(error.toString());
    }
  }

  void _toggleButtonActive(final bool shouldEnable) {
    setState(() {
      _isDisabled = !shouldEnable;
    });
  }

  void _showErrorAndClose(final String errorMessage) {
    FlutterwaveViewUtils.showToast(widget.mainContext, errorMessage);
    Navigator.pop(widget.mainContext, null); // return response to user
  }

  void _showConfirmDialog() {
    FlutterwaveViewUtils.showConfirmPaymentModal(widget.mainContext, selectedCurrency, _currentAmount, widget.style.getMainTextStyle(),
        widget.style.getDialogBackgroundColor(), widget.style.getDialogCancelTextStyle(), widget.style.getDialogContinueTextStyle(), _handlePayment);
  }

  @override
  onTransactionError() {
    _showErrorAndClose("transaction error");
  }

  @override
  onCancelled() {
    FlutterwaveViewUtils.showToast(widget.mainContext, "Transaction Cancelled");
    Navigator.pop(widget.mainContext, null);
  }

  @override
  onTransactionSuccess(String id, String txRef) {
    final ChargeResponse? chargeResponse = ChargeResponse(status: "success", success: true, transactionId: id, txRef: txRef);
    Navigator.pop(this.widget.mainContext, chargeResponse);
  }
}
