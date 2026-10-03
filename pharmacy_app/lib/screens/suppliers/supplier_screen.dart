import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_sizes.dart';
import '../../config/app_text_styles.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/search_bar_widget.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().loadSuppliers();
    });
  }

  Future<void> _showSupplierForm({
    Supplier? supplier,
  }) async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: supplier?.name ?? '',
    );
    final companyController = TextEditingController(
      text: supplier?.companyName ?? '',
    );
    final contactController = TextEditingController(
      text: supplier?.contactPerson ?? '',
    );
    final emailController = TextEditingController(
      text: supplier?.email ?? '',
    );
    final phoneController = TextEditingController(
      text: supplier?.phoneNumber ?? '',
    );
    final addressController = TextEditingController(
      text: supplier?.address ?? '',
    );

    bool isActive = supplier?.isActive ?? true;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  supplier == null
                      ? 'Add Supplier'
                      : 'Edit Supplier',
                  style: AppTextStyles.headingMedium,
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText: 'Supplier name',
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Enter supplier name.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(
                          height: AppSizes.spacingMedium,
                        ),
                        TextFormField(
                          controller: companyController,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            hintText: 'Company name',
                          ),
                        ),
                        const SizedBox(
                          height: AppSizes.spacingMedium,
                        ),
                        TextFormField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Person',
                            hintText: 'Contact person',
                          ),
                        ),
                        const SizedBox(
                          height: AppSizes.spacingMedium,
                        ),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'supplier@example.com',
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return null;
                            }

                            if (!value.contains('@')) {
                              return 'Enter a valid email.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(
                          height: AppSizes.spacingMedium,
                        ),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Phone number',
                          ),
                        ),
                        const SizedBox(
                          height: AppSizes.spacingMedium,
                        ),
                        TextFormField(
                          controller: addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            hintText: 'Supplier address',
                          ),
                        ),
                        if (supplier != null) ...[
                          const SizedBox(
                            height: AppSizes.spacingSmall,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Active supplier',
                            ),
                            value: isActive,
                            onChanged: (value) {
                              setDialogState(() {
                                isActive = value;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      final provider =
                          context.read<SupplierProvider>();

                      final supplierData = Supplier(
                        id: supplier?.id ?? 0,
                        name: nameController.text.trim(),
                        companyName:
                            companyController.text.trim(),
                        contactPerson:
                            contactController.text.trim(),
                        email: emailController.text.trim(),
                        phoneNumber:
                            phoneController.text.trim(),
                        address:
                            addressController.text.trim(),
                        isActive: isActive,
                        createdAt:
                            supplier?.createdAt ?? '',
                        updatedAt:
                            supplier?.updatedAt ?? '',
                      );

                      final success = supplier == null
                          ? await provider.createSupplier(
                              supplierData,
                            )
                          : await provider.updateSupplier(
                              supplierData,
                            );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      if (success) {
                        Navigator.of(dialogContext).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              supplier == null
                                  ? 'Supplier created successfully.'
                                  : 'Supplier updated successfully.',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.error ??
                                  'Operation failed.',
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      supplier == null ? 'Create' : 'Save',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      companyController.dispose();
      contactController.dispose();
      emailController.dispose();
      phoneController.dispose();
      addressController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Suppliers',
          style: AppTextStyles.headingMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'Add supplier',
            onPressed: () {
              _showSupplierForm();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Consumer<SupplierProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading &&
              provider.suppliers.isEmpty) {
            return const LoadingWidget();
          }

          if (provider.error != null &&
              provider.suppliers.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: provider.loadSuppliers,
            );
          }

          final suppliers = provider.suppliers.where((supplier) {
            final query = _searchQuery.toLowerCase();

            return supplier.name
                    .toLowerCase()
                    .contains(query) ||
                supplier.companyName
                    .toLowerCase()
                    .contains(query) ||
                supplier.contactPerson
                    .toLowerCase()
                    .contains(query) ||
                supplier.phoneNumber
                    .toLowerCase()
                    .contains(query);
          }).toList();

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(
                AppSizes.paddingMedium,
              ),
              children: [
                SearchBarWidget(
                  hintText: 'Search suppliers...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(
                  height: AppSizes.spacingMedium,
                ),
                if (suppliers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'No suppliers found.',
                      ),
                    ),
                  )
                else
                  ...suppliers.map(
                    (supplier) => Card(
                      margin: const EdgeInsets.only(
                        bottom: AppSizes.spacingSmall,
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal:
                              AppSizes.paddingMedium,
                          vertical:
                              AppSizes.paddingSmall,
                        ),
                        leading: CircleAvatar(
                          child: Text(
                            supplier.name.isNotEmpty
                                ? supplier.name[0]
                                    .toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(
                          supplier.name,
                          style:
                              AppTextStyles.headingSmall,
                        ),
                        subtitle: Padding(
                          padding:
                              const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                supplier.companyName.isNotEmpty
                                    ? supplier.companyName
                                    : supplier.contactPerson,
                                style:
                                    AppTextStyles.bodySmall,
                              ),
                              if (supplier.phoneNumber
                                  .isNotEmpty)
                                Text(
                                  supplier.phoneNumber,
                                  style:
                                      AppTextStyles.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              supplier.isActive
                                  ? Icons
                                      .check_circle_outline
                                  : Icons
                                      .pause_circle_outline,
                              size: 22,
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showSupplierForm(
                                    supplier: supplier,
                                  );
                                }
                              },
                              itemBuilder: (context) {
                                return const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                ];
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}