import 'package:flutter/widgets.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/extensions/context_extensions.dart';

String customerErrorMessage(BuildContext context, AppErrorCode code) =>
    switch (code) {
      AppErrorCode.database => context.l10n.customerErrorDatabase,
      AppErrorCode.storage => context.l10n.customerErrorStorage,
      AppErrorCode.network => context.l10n.customerErrorNetwork,
      AppErrorCode.auth => context.l10n.customerErrorAuth,
      AppErrorCode.contactPicker => context.l10n.customerErrorPicker,
      AppErrorCode.validation => context.l10n.customerErrorValidation,
      AppErrorCode.unexpected => context.l10n.customerErrorUnexpected,
    };
