import '../models/lesson.dart';

/// Curated, built-in learning content for the "Learn" hub.
///
/// This is static reference content (chess rules, strategy principles,
/// tactical motifs, opening theory) rather than per-user data, so it ships
/// with the app instead of being fetched from Firestore.
class ChessCurriculumData {
  ChessCurriculumData._();

  static final DateTime _publishedDate = DateTime(2026, 1, 1);

  // ---------------------------------------------------------------------
  // How to play: piece movement tutorial (beginner-friendly)
  // ---------------------------------------------------------------------

  static final List<PieceMovementStep> pieceMovementSteps = [
    const PieceMovementStep(
      pieceName: 'ポーン (Pawn)',
      symbol: '♟',
      summary: '前にしか進めない、最も数が多い駒です。',
      details: [
        '通常は1マス前に進みます。',
        '最初の1手だけ、2マス前に進めます。',
        '相手の駒を取るときだけ、斜め前に1マス動けます。',
        '相手側の端まで到達すると、他の駒(通常はクイーン)に昇格できます。',
      ],
      highlightSquares: ['e3', 'e4'],
      pieceSquare: 'e2',
    ),
    const PieceMovementStep(
      pieceName: 'ナイト (Knight)',
      symbol: '♞',
      summary: 'アルファベットの「L字」に動く、唯一他の駒を飛び越えられる駒です。',
      details: [
        '縦に2マス+横に1マス、または横に2マス+縦に1マス動きます。',
        '他の駒の上を飛び越えて移動できます。',
        '盤の中央にいるほど、動ける範囲が広がります。',
      ],
      highlightSquares: ['e2', 'e6', 'c3', 'c5', 'f3', 'f5', 'g4', 'g6'],
      pieceSquare: 'd4',
    ),
    const PieceMovementStep(
      pieceName: 'ビショップ (Bishop)',
      symbol: '♝',
      summary: '斜め方向にどこまでも進める駒です。1つの色のマスしか使えません。',
      details: [
        '斜め方向であれば、何マスでも進めます。',
        '他の駒を飛び越えることはできません。',
        '各プレイヤーは白マス用・黒マス用の2体を持ちます。',
      ],
      highlightSquares: [
        'a1',
        'b2',
        'c3',
        'e5',
        'f6',
        'g7',
        'h8',
        'a7',
        'b6',
        'c5',
        'e3',
        'f2',
        'g1',
      ],
      pieceSquare: 'd4',
    ),
    const PieceMovementStep(
      pieceName: 'ルーク (Rook)',
      symbol: '♜',
      summary: '縦・横方向にどこまでも進める駒です。',
      details: [
        '縦方向・横方向であれば、何マスでも進めます。',
        '他の駒を飛び越えることはできません。',
        '特定の条件下で、キングと「キャスリング」という特殊な動きができます。',
      ],
      highlightSquares: [
        'd1',
        'd2',
        'd3',
        'd5',
        'd6',
        'd7',
        'd8',
        'a4',
        'b4',
        'c4',
        'e4',
        'f4',
        'g4',
        'h4',
      ],
      pieceSquare: 'd4',
    ),
    const PieceMovementStep(
      pieceName: 'クイーン (Queen)',
      symbol: '♛',
      summary: '最も強力な駒。縦・横・斜め、すべての方向にどこまでも進めます。',
      details: [
        'ルークとビショップの動きを組み合わせた最強の駒です。',
        '縦・横・斜め、どの方向にも何マスでも進めます。',
        '序盤で早く動かしすぎると、相手の駒に狙われやすいので注意しましょう。',
      ],
      highlightSquares: [
        'd1',
        'd2',
        'd3',
        'd5',
        'd6',
        'd7',
        'd8',
        'a4',
        'b4',
        'c4',
        'e4',
        'f4',
        'g4',
        'h4',
        'a1',
        'b2',
        'c3',
        'e5',
        'f6',
        'g7',
        'h8',
        'a7',
        'b6',
        'c5',
        'e3',
        'f2',
        'g1',
      ],
      pieceSquare: 'd4',
    ),
    const PieceMovementStep(
      pieceName: 'キング (King)',
      symbol: '♚',
      summary: 'このゲームの主役。周囲1マスだけ動けますが、取られたら負けです。',
      details: [
        '縦・横・斜め、どの方向にも1マスだけ動けます。',
        'キングが「チェック」(次に取られる状態)から逃げられなくなると「チェックメイト」で負けです。',
        '特定の条件下で、ルークと「キャスリング」という2マス移動ができます。',
      ],
      highlightSquares: [
        'c3',
        'd3',
        'e3',
        'c4',
        'e4',
        'c5',
        'd5',
        'e5',
      ],
      pieceSquare: 'd4',
    ),
  ];

  static const List<String> gameBasics = [
    'チェスは2人で対局し、白が先手で始めます。',
    '目的は相手のキングを「チェックメイト」(逃げ場のないチェック)にすることです。',
    '各プレイヤーは1手ずつ交互に駒を動かします。',
    '相手の駒がいるマスに自分の駒を動かすと、その駒を「取る」ことができます。',
    '自分のキングがチェックされている間は、チェックを防ぐ手しか指せません。',
  ];

  // ---------------------------------------------------------------------
  // Strategy guides
  // ---------------------------------------------------------------------

  static final List<StrategyGuide> strategyGuides = [
    StrategyGuide(
      id: 'strategy_opening_principles',
      title: '序盤の3原則',
      description: '序盤で何を優先すべきかを示す、最も基本的な指針です。',
      difficulty: DifficultyLevel.beginner,
      principlesPgn: const [],
      keyConceptsExplained: const [
        '中央支配: e4・d4・e5・d5の中央4マスをコントロールする。',
        '駒の展開: ナイトとビショップを早めに活用できるマスへ développer する。',
        'キングの安全: 早めにキャスリングを行い、キングを安全な位置に移す。',
      ],
      positionEvaluationCriteria: const [
        '中央のマスをどちらがより多く支配しているか。',
        '軽い駒(ナイト・ビショップ)がすでに活動的なマスに出ているか。',
        'キングがキャスリング済みで安全か。',
      ],
      planFormationGuidelines: const [
        '同じ駒を2度動かす手は、明確な理由がない限り避ける。',
        '序盤でクイーンを早く出しすぎない(相手の駒に狙われて手数を損する)。',
        'ポーンを動かしすぎず、駒の展開を優先する。',
      ],
      endgameTransitionTips: const [],
      relatedStrategies: const [
        'strategy_piece_activity',
        'strategy_king_safety'
      ],
      createdDate: _publishedDate,
    ),
    StrategyGuide(
      id: 'strategy_piece_activity',
      title: '駒の活動性を高める',
      description: '駒の価値は「どれだけ働けているか」で決まります。',
      difficulty: DifficultyLevel.intermediate,
      principlesPgn: const [],
      keyConceptsExplained: const [
        '活動的な駒: 多くのマスに利きがあり、盤面に影響を与えられる駒。',
        '悪いビショップ: 自分のポーンに動きを塞がれて可動域が狭いビショップ。',
        'アウトポスト: 相手のポーンに追い払われない、敵陣近くの安定したマス。',
      ],
      positionEvaluationCriteria: const [
        '自分の駒がそれぞれ何マスをコントロールしているか。',
        '相手の駒に比べて、自分の駒はより良いマスにいるか。',
        '受動的で働いていない駒(特にルーク)はないか。',
      ],
      planFormationGuidelines: const [
        '働いていない駒があれば、それを活性化する手を優先的に探す。',
        'オープンファイル(ポーンのない縦列)にルークを配置する。',
        'ナイトを敵陣に近いアウトポストへ進出させる。',
      ],
      endgameTransitionTips: const [
        '終盤ではキングも積極的な駒として活用する。',
      ],
      relatedStrategies: const [
        'strategy_opening_principles',
        'strategy_pawn_structure'
      ],
      createdDate: _publishedDate,
    ),
    StrategyGuide(
      id: 'strategy_king_safety',
      title: 'キングの安全確保',
      description: 'どれだけ駒得をしても、キングが危険では意味がありません。',
      difficulty: DifficultyLevel.beginner,
      principlesPgn: const [],
      keyConceptsExplained: const [
        'キャスリング: キングを中央から離し、ルークを活性化させる特殊な手。',
        'ポーンシールド: キャスリング後のキングを守るポーンの並び。',
        'オープンキング: 周囲のポーンが崩れ、攻撃を受けやすくなったキング。',
      ],
      positionEvaluationCriteria: const [
        'キングはすでにキャスリング済みか。',
        'キング周辺のポーン構造は崩れていないか。',
        '相手の駒がキング方面に集中していないか。',
      ],
      planFormationGuidelines: const [
        '特別な理由がない限り、序盤10手以内にキャスリングする。',
        'キング周辺のポーンをむやみに動かさない。',
        '攻撃を受けたら、駒の損得よりキングの安全を優先することもある。',
      ],
      endgameTransitionTips: const [
        '終盤で駒が減ったら、キングの安全より活動性を優先することが多い。',
      ],
      relatedStrategies: const ['strategy_opening_principles'],
      createdDate: _publishedDate,
    ),
    StrategyGuide(
      id: 'strategy_pawn_structure',
      title: 'ポーン構造の基礎',
      description: 'ポーンは「魂」とも呼ばれ、局面の性格を決定づけます。',
      difficulty: DifficultyLevel.advanced,
      principlesPgn: const [],
      keyConceptsExplained: const [
        '孤立ポーン: 隣接する縦列に味方ポーンがいない、守りにくいポーン。',
        '連結ポーン: 互いに守り合える、隣接する縦列のポーン。',
        'パスポーン: 相手ポーンに止められる見込みがなく、昇格しやすいポーン。',
      ],
      positionEvaluationCriteria: const [
        '弱いポーン(孤立・後退)は存在するか。',
        'どちらかにパスポーンが生まれる可能性はあるか。',
        'ポーン構造は攻撃向きか、守備向きか。',
      ],
      planFormationGuidelines: const [
        '相手の弱いポーンを標的にした駒配置を計画する。',
        '自分の弱いポーンをできるだけ駒で守るか、交換して解消する。',
        '終盤を見据え、パスポーンを作れる構造を目指す。',
      ],
      endgameTransitionTips: const [
        '終盤ではパスポーンの有無が勝敗を大きく左右する。',
      ],
      relatedStrategies: const ['strategy_piece_activity'],
      createdDate: _publishedDate,
    ),
  ];

  // ---------------------------------------------------------------------
  // Tactics patterns
  // ---------------------------------------------------------------------

  static final List<TacticsPattern> tacticsPatterns = [
    TacticsPattern(
      id: 'tactic_fork',
      name: 'フォーク (Fork)',
      description: '1つの駒で、相手の2つ以上の駒を同時に攻撃する手筋です。',
      difficulty: DifficultyLevel.beginner,
      examplePositionsPgn: const [],
      recognitionFeatures: const [
        '相手の2つの駒が、自分の駒(特にナイト)の利きに同時に入るマスがないか探す。',
        '相手のキングとクイーン(または他の価値の高い駒)が近くにいる局面で特に狙いやすい。',
      ],
      executionSteps: const [
        '2つ以上の相手の駒を同時に攻撃できるマスを探す。',
        'そのマスに自分の駒を移動できるか、安全に着地できるかを確認する。',
        '相手はどちらか一方の駒しか守れないため、もう一方を獲得する。',
      ],
      relatedTactics: const ['tactic_pin', 'tactic_double_attack'],
      motif: 'multi_attack',
      typicalOccurrenceFrequency: 5,
      createdDate: _publishedDate,
    ),
    TacticsPattern(
      id: 'tactic_pin',
      name: 'ピン (Pin)',
      description: '駒が動くと、その後ろのより価値の高い駒(または王)が危険になるため動けなくなる状態です。',
      difficulty: DifficultyLevel.beginner,
      examplePositionsPgn: const [],
      recognitionFeatures: const [
        '相手の駒とキング(または高価値の駒)が、同じ縦・横・斜めのライン上に並んでいる。',
        'そのラインに利きを持つ自分のルーク・ビショップ・クイーンがあるか確認する。',
      ],
      executionSteps: const [
        'ピンされている駒をさらに攻撃し、身動きが取れない状況を利用する。',
        'ピンされている駒の後ろの駒(キングなど)を直接狙う手を探す。',
      ],
      relatedTactics: const ['tactic_skewer', 'tactic_fork'],
      motif: 'line_attack',
      typicalOccurrenceFrequency: 4,
      createdDate: _publishedDate,
    ),
    TacticsPattern(
      id: 'tactic_skewer',
      name: 'スキュワー (Skewer)',
      description: 'ピンの逆で、価値の高い駒を先に攻撃し、それが逃げると後ろの駒が取られる手筋です。',
      difficulty: DifficultyLevel.intermediate,
      examplePositionsPgn: const [],
      recognitionFeatures: const [
        '相手の価値の高い駒(キングやクイーン)の後ろに、価値の低い駒が同一ライン上にある。',
        'そのラインに利きを持つ自分のルーク・ビショップ・クイーンがあるか確認する。',
      ],
      executionSteps: const [
        '価値の高い駒を直接攻撃する。',
        '相手がその駒を逃がすと、後ろの駒が無防備になるため獲得する。',
      ],
      relatedTactics: const ['tactic_pin'],
      motif: 'line_attack',
      typicalOccurrenceFrequency: 2,
      createdDate: _publishedDate,
    ),
    TacticsPattern(
      id: 'tactic_discovered_attack',
      name: 'ディスカバードアタック (Discovered Attack)',
      description: '1つの駒を動かすことで、後ろに隠れていた別の駒の利きが開き、攻撃が生まれる手筋です。',
      difficulty: DifficultyLevel.advanced,
      examplePositionsPgn: const [],
      recognitionFeatures: const [
        '自分の駒(ルーク・ビショップ・クイーン)の利きを、自分の別の駒が塞いでいる。',
        'その塞いでいる駒を動かすと、相手の重要な駒に新たな攻撃が生まれるか確認する。',
      ],
      executionSteps: const [
        '塞いでいる駒自体にも、動くことで攻撃や脅威を作れないか検討する。',
        '2つの脅威(動いた駒の攻撃+開いた利きの攻撃)を同時に作れると特に強力。',
      ],
      relatedTactics: const ['tactic_fork'],
      motif: 'discovered',
      typicalOccurrenceFrequency: 2,
      createdDate: _publishedDate,
    ),
    TacticsPattern(
      id: 'tactic_back_rank',
      name: 'バックランクメイト (Back Rank Mate)',
      description: '自陣最終ラインのポーンにキングの逃げ場を塞がれ、ルークやクイーンにメイトされる手筋です。',
      difficulty: DifficultyLevel.intermediate,
      examplePositionsPgn: const [],
      recognitionFeatures: const [
        '相手のキングが最終ラインにおり、周囲のポーンが1段も動いていない。',
        '自分のルークやクイーンが、そのラインに侵入できるオープンファイルを持っているか確認する。',
      ],
      executionSteps: const [
        '最終ラインに利きを通せるルーク・クイーンの侵入経路を探す。',
        'キングの逃げ場(ポーンの隙間)がないことを確認してから侵入する。',
      ],
      relatedTactics: const [],
      motif: 'mating_pattern',
      typicalOccurrenceFrequency: 3,
      createdDate: _publishedDate,
    ),
  ];

  // ---------------------------------------------------------------------
  // Opening course (Chessable-style structured curriculum)
  // ---------------------------------------------------------------------

  static final List<OpeningExplanation> openingCourse = [
    OpeningExplanation(
      id: 'opening_italian',
      name: 'イタリアンゲーム',
      ecoCode: 'C50',
      description: '1.e4 e5 2.Nf3 Nc6 3.Bc4 から始まる、初心者に最もおすすめのオープニングです。',
      difficulty: DifficultyLevel.beginner,
      mainLinesPgn: const ['1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5'],
      alternativeLinesPgn: const ['1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6'],
      strategicIdeas: const [
        'ビショップをc4に展開し、f7の弱点を早期から狙う。',
        '中央への駒の展開を素早く行い、キャスリングを急ぐ。',
      ],
      typicalPlans: const [
        'キングサイドへのキャスリング後、中央突破やキングサイド攻撃を狙う。',
      ],
      commonTrapsPgn: const [
        '4.c3 Nf6 5.d4 exd4 6.cxd4 Bb4+ の展開に注意(フリード・リエブラフスキー・アタック)。',
      ],
      historyNotes: const ['チェス史上最も古くから知られるオープニングの1つ。'],
      statistics: const {'popularity': 0.8},
      totalGamesWithOpening: 0,
      winRateWhite: 0.36,
      winRateBlack: 0.32,
      drawRate: 0.32,
      createdDate: _publishedDate,
    ),
    OpeningExplanation(
      id: 'opening_ruy_lopez',
      name: 'ルイロペス(スペインの戦法)',
      ecoCode: 'C60',
      description: '1.e4 e5 2.Nf3 Nc6 3.Bb5 から始まる、最も歴史あるオープニングの1つです。',
      difficulty: DifficultyLevel.intermediate,
      mainLinesPgn: const ['1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6'],
      alternativeLinesPgn: const ['1. e4 e5 2. Nf3 Nc6 3. Bb5 Nf6'],
      strategicIdeas: const [
        'c6のナイトへの間接的なプレッシャーを通じて、e5ポーンを長期的に標的にする。',
        '中央の緊張を保ちながら、じっくりとポジションを積み上げる。',
      ],
      typicalPlans: const [
        'クローズド・ルイロペスでは、d4-d5の中央突破やキングサイド攻撃を計画する。',
      ],
      commonTrapsPgn: const [],
      historyNotes: const ['16世紀のスペインの司祭ルイ・ロペスにちなんで名付けられた。'],
      statistics: const {'popularity': 0.9},
      totalGamesWithOpening: 0,
      winRateWhite: 0.37,
      winRateBlack: 0.30,
      drawRate: 0.33,
      createdDate: _publishedDate,
    ),
    OpeningExplanation(
      id: 'opening_sicilian',
      name: 'シシリアン・ディフェンス',
      ecoCode: 'B20',
      description: '1.e4 c5 から始まる、黒の最も人気で戦闘的なオープニングです。',
      difficulty: DifficultyLevel.advanced,
      mainLinesPgn: const ['1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6'],
      alternativeLinesPgn: const ['1. e4 c5 2. Nf3 Nc6'],
      strategicIdeas: const [
        '中央を非対称にすることで、白と対等以上の勝負を目指す。',
        'クイーンサイドでの反撃(...b5、...a5など)を計画する。',
      ],
      typicalPlans: const [
        '黒はクイーンサイドの駒を活用した反撃を、白はキングサイド攻撃を狙うことが多い。',
      ],
      commonTrapsPgn: const [],
      historyNotes: const ['プロの対局で最も指される、黒の1.e4への応手。'],
      statistics: const {'popularity': 0.95},
      totalGamesWithOpening: 0,
      winRateWhite: 0.35,
      winRateBlack: 0.33,
      drawRate: 0.32,
      createdDate: _publishedDate,
    ),
    OpeningExplanation(
      id: 'opening_queens_gambit',
      name: 'クイーンズ・ギャンビット',
      ecoCode: 'D06',
      description: '1.d4 d5 2.c4 から始まる、白の代表的な1手目1.d4への継続手です。',
      difficulty: DifficultyLevel.intermediate,
      mainLinesPgn: const ['1. d4 d5 2. c4 e6 3. Nc3 Nf6'],
      alternativeLinesPgn: const ['1. d4 d5 2. c4 c6'],
      strategicIdeas: const [
        '一時的にポーンを犠牲にする(取り返せる)ことで、中央支配と駒の展開を得る。',
        'クイーンズ・ギャンビット・デクラインドでは堅実な陣形の構築を目指す。',
      ],
      typicalPlans: const [
        '白は中央のスペース優位を活かした展開を、黒は堅実な構えからのカウンタープレイを狙う。',
      ],
      commonTrapsPgn: const [],
      historyNotes: const ['「ギャンビット」という名前だが、実際にポーンを保持できることは稀。'],
      statistics: const {'popularity': 0.7},
      totalGamesWithOpening: 0,
      winRateWhite: 0.38,
      winRateBlack: 0.29,
      drawRate: 0.33,
      createdDate: _publishedDate,
    ),
    OpeningExplanation(
      id: 'opening_french',
      name: 'フレンチ・ディフェンス',
      ecoCode: 'C00',
      description: '1.e4 e6 から始まる、堅実な構造を重視する黒のオープニングです。',
      difficulty: DifficultyLevel.intermediate,
      mainLinesPgn: const ['1. e4 e6 2. d4 d5'],
      alternativeLinesPgn: const [],
      strategicIdeas: const [
        'd5でポーン構造の緊張を作り、堅実な陣形からのカウンタープレイを狙う。',
        '自陣の光線ビショップ(c8のビショップ)の活用が長期的な課題になりやすい。',
      ],
      typicalPlans: const [
        'クイーンサイドでの...c5による反撃を計画することが多い。',
      ],
      commonTrapsPgn: const [],
      historyNotes: const [],
      statistics: const {'popularity': 0.6},
      totalGamesWithOpening: 0,
      winRateWhite: 0.37,
      winRateBlack: 0.31,
      drawRate: 0.32,
      createdDate: _publishedDate,
    ),
  ];
}

/// A single step in the beginner "how the pieces move" tutorial.
///
/// Deliberately not a freezed model: this is purely static, bundled
/// tutorial content, not data that flows through Firestore or providers.
class PieceMovementStep {
  const PieceMovementStep({
    required this.pieceName,
    required this.symbol,
    required this.summary,
    required this.details,
    required this.highlightSquares,
    required this.pieceSquare,
  });
  final String pieceName;
  final String symbol;
  final String summary;
  final List<String> details;

  /// Algebraic squares (e.g. 'e4') to highlight as legal destinations.
  final List<String> highlightSquares;

  /// The square the piece itself sits on for this illustration.
  final String pieceSquare;
}
