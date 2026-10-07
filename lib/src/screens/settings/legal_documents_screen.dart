import 'package:flutter/material.dart';

class LegalDocumentsScreen extends StatelessWidget {
  // 'privacy' or 'terms'

  const LegalDocumentsScreen({
    required this.documentType,
    Key? key,
  }) : super(key: key);
  final String documentType;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            documentType == 'privacy' ? 'Privacy Policy' : 'Terms of Service',
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documentType == 'privacy'
                      ? 'Privacy Policy'
                      : 'Terms of Service',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Last updated: September 11, 2026',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 24),
                if (documentType == 'privacy')
                  _buildPrivacyPolicy(context)
                else
                  _buildTermsOfService(context),
              ],
            ),
          ),
        ),
      );

  Widget _buildPrivacyPolicy(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            context,
            '1. Introduction',
            'Chess Tactics Master ("we", "us", or "our") operates the Chess Tactics Master app. '
                'This page informs you of our policies regarding the collection, use, and disclosure of personal data when you use our app.',
          ),
          _buildSection(
            context,
            '2. Information Collection',
            'We collect several different types of information for various purposes to provide and improve our app:\n\n'
                '• Account Information: Display name, email address, profile picture\n'
                '• Game Data: Chess game history, moves, ratings, statistics\n'
                '• Device Information: Device type, operating system, app version\n'
                '• Usage Analytics: Features used, session duration, in-app actions\n'
                '• Location Data: Approximate location (with permission)',
          ),
          _buildSection(
            context,
            '3. Use of Data',
            'We use the collected data for various purposes:\n\n'
                '• To provide and maintain our app\n'
                '• To notify you about changes to our app\n'
                '• To allow you to participate in interactive features\n'
                '• To analyze usage patterns and improve user experience\n'
                '• To monitor and analyze trends and usage\n'
                '• To detect, prevent, and address technical issues',
          ),
          _buildSection(
            context,
            '4. Security',
            'The security of your data is important to us, but remember that no method of transmission over the internet is 100% secure. '
                'While we strive to use commercially acceptable means to protect your personal data, we cannot guarantee its absolute security.',
          ),
          _buildSection(
            context,
            '5. Changes to Privacy Policy',
            'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page '
                'and updating the "Last updated" date at the top of this page.',
          ),
          _buildSection(
            context,
            '6. Contact Us',
            'If you have any questions about this Privacy Policy, please contact us at support@chessmaster.app',
          ),
        ],
      );

  Widget _buildTermsOfService(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            context,
            '1. Acceptance of Terms',
            'By accessing and using the Chess Tactics Master app, you accept and agree to be bound by the terms '
                'and provision of this agreement.',
          ),
          _buildSection(
            context,
            '2. Use License',
            'Permission is granted to temporarily download one copy of the materials (information or software) on Chess Tactics Master for personal, '
                'non-commercial transitory viewing only. This is the grant of a license, not a transfer of title, and under this license you may not:\n\n'
                '• Modify or copy the materials\n'
                '• Use the materials for any commercial purpose or for any public display\n'
                '• Attempt to reverse engineer any software contained on the app\n'
                '• Remove any copyright or other proprietary notations from the materials\n'
                '• Transfer the materials to another person or "mirror" the materials on any other server',
          ),
          _buildSection(
            context,
            '3. Disclaimer',
            'The materials on Chess Tactics Master are provided on an "as is" basis. Chess Tactics Master makes no warranties, expressed or implied, '
                'and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, '
                'fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights.',
          ),
          _buildSection(
            context,
            '4. Limitations',
            'In no event shall Chess Tactics Master or its suppliers be liable for any damages (including, without limitation, damages for loss of data '
                'or profit, or due to business interruption) arising out of the use or inability to use the materials on the Chess Tactics Master app, '
                'even if we or our authorized representative has been notified orally or in writing of the possibility of such damage.',
          ),
          _buildSection(
            context,
            '5. Accuracy of Materials',
            'The materials appearing on Chess Tactics Master could include technical, typographical, or photographic errors. '
                'Chess Tactics Master does not warrant that any of the materials on its app are accurate, complete, or current. '
                'Chess Tactics Master may make changes to the materials contained on its app at any time without notice.',
          ),
          _buildSection(
            context,
            '6. Links',
            'Chess Tactics Master has not reviewed all of the sites linked to its app and is not responsible for the contents of any such linked site. '
                'The inclusion of any link does not imply endorsement by Chess Tactics Master of the site. Use of any such linked website is at the user\'s own risk.',
          ),
          _buildSection(
            context,
            '7. Modifications',
            'Chess Tactics Master may revise these terms of service for its app at any time without notice. '
                'By using this app, you are agreeing to be bound by the then current version of these terms of service.',
          ),
          _buildSection(
            context,
            '8. Governing Law',
            'These terms and conditions are governed by and construed in accordance with the laws of the jurisdiction in which Chess Tactics Master operates, '
                'and you irrevocably submit to the exclusive jurisdiction of the courts in that location.',
          ),
        ],
      );

  Widget _buildSection(BuildContext context, String title, String content) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
        ],
      );
}
