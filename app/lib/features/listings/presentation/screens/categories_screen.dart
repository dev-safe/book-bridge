import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/core/constants/categories.dart';
import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const categories = appCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.categories),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              AppLocalizations.of(context)!.whatIsYourInterest,
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final name = category.name;
                final icon = category.icon;
                final color = category.color;

                return GestureDetector(
                  onTap: () {
                    // Set the category in HomeViewModel and navigate to Home
                    context.read<HomeViewModel>().setSelectedCategory(name);
                    context.go('/home');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 32, color: color),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getLocalizedCategory(context, name),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedCategory(BuildContext context, String categoryName) {
    final l10n = AppLocalizations.of(context)!;
    switch (categoryName) {
      case 'Textbooks':
        return l10n.categoryTextbooks;
      case 'Fiction':
        return l10n.categoryFiction;
      case 'Science':
        return l10n.categoryScience;
      case 'History':
        return l10n.categoryHistory;
      case 'GCE':
        return l10n.categoryGCE;
      case 'Business':
        return l10n.categoryBusiness;
      case 'Technology':
        return l10n.categoryTechnology;
      case 'Arts':
        return l10n.categoryArts;
      case 'Language':
        return l10n.categoryLanguage;
      case 'Mathematics':
        return l10n.categoryMathematics;
      case 'Engineering':
        return l10n.categoryEngineering;
      case 'Medicine':
        return l10n.categoryMedicine;
      default:
        return categoryName;
    }
  }
}
