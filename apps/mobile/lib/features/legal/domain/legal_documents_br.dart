const String kNexusTermsVersion = '1.0.0-br';
const String kNexusPrivacyVersion = '1.0.0-br';

class LegalSection {
  const LegalSection({
    required this.title,
    required this.legalBasis,
    required this.body,
  });

  final String title;
  final String legalBasis;
  final String body;
}

class LegalDocumentTab {
  const LegalDocumentTab({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.sections,
  });

  final String id;
  final String label;
  final String subtitle;
  final List<LegalSection> sections;
}

abstract final class LegalDocumentsBr {
  static const List<LegalDocumentTab> tabs = <LegalDocumentTab>[
    LegalDocumentTab(
      id: 'terms',
      label: 'Termos de Uso',
      subtitle:
          'Termos Gerais de Uso, Capacidade Civil (18+), Propriedade Intelectual, CDC e Foro · Versão $kNexusTermsVersion',
      sections: <LegalSection>[
        LegalSection(
          title: '1. Objeto, Aceitação e Idade Mínima Obrigatória (18+)',
          legalBasis: 'Código Civil (Arts. 5º e 104) · ECA (Lei nº 8.069/1990)',
          body:
              'O NEXUS DUO é uma plataforma de relacionamento social e conexão gamer para formação de duplas em jogos e vínculos afetivos ou de amizade entre pessoas maiores de 18 (dezoito) anos com plena capacidade civil. É estritamente proibido o cadastro, acesso ou uso por menores de 18 anos. O sistema aplica validação declaratória no cadastro com registro auditável e trava estrutural de banco de dados (CHECK >= 18 anos). Contas suspeitas de uso por menor serão encerradas imediatamente.',
        ),
        LegalSection(
          title: '2. Conta, Política de Senha e Responsabilidade de Acesso',
          legalBasis: 'Marco Civil (Lei nº 12.965/2014) · Segurança Digital',
          body:
              'O acesso ocorre com validação por código OTP de 6 dígitos enviado por e-mail e política rígida de senha (8 a 12 caracteres, letras maiúsculas e minúsculas, números, caractere especial e bloqueio de nomes próprios ou partes do e-mail). Suas credenciais e sua chave privada E2EE local são pessoais e intransferíveis. Em conformidade com o Art. 15 da Lei nº 12.965/2014, registros essenciais de acesso à aplicação podem ser preservados sob sigilo pelo prazo legal mínimo de 6 (seis) meses.',
        ),
        LegalSection(
          title: '3. Código Civil, Conteúdo do Usuário e Direito de Imagem',
          legalBasis: 'Código Civil (Arts. 11 a 21 e 186)',
          body:
              'Você permanece titular de suas fotos, biografia e preferências enviadas ao aplicativo, concedendo ao NEXUS DUO licença gratuita, não exclusiva e imediatamente revogável para exibição no fluxo de descoberta e chat exclusivamente enquanto sua conta permanecer ativa. É proibido publicar fotos de terceiros sem autorização, falsificar identidade ou violar direitos da personalidade (imagem, honra, voz e intimidade).',
        ),
        LegalSection(
          title: '4. Direito do Consumidor e Serviços Gratuitos / Futuros',
          legalBasis:
              'CDC (Lei nº 8.078/1990, Arts. 6º, 49 e 51) · Dec. 7.962/2013',
          body:
              'Os recursos essenciais do MVP do NEXUS DUO são oferecidos gratuitamente e sem práticas enganosas ("dark patterns"). Caso venham a ser ofertados planos ou recursos opcionais pagos no futuro, preços, vigência, renovação e canais fáceis de cancelamento serão informados previamente de forma ostensiva, assegurando o direito de arrependimento em até 7 (sete) dias corridos (Art. 49 do CDC) e nulidade de qualquer cláusula abusiva (Art. 51).',
        ),
        LegalSection(
          title: '5. Propriedade Intelectual e Marcas de Terceiros',
          legalBasis: 'Leis nº 9.610/1998 (LDA), 9.279/1996 (LPI) e 9.609/1998',
          body:
              'O código-fonte, design Cyber-Velvet & Obsidian Neon, algoritmos de compatibilidade e marca NEXUS DUO são protegidos pela legislação de propriedade intelectual. É proibido praticar scraping, engenharia reversa maliciosa, uso de bots ou spam. Nomes de jogos e plataformas mencionados no catálogo (como Valorant, League of Legends, CS2, Steam, Discord, Riot Games, Valve) pertencem a seus respectivos titulares e são exibidos apenas em caráter nominativo e informativo de compatibilidade, sem vínculo de patrocínio ou endosso.',
        ),
        LegalSection(
          title:
              '6. Distribuição APK Assinada, Legislação Aplicável e Governança',
          legalBasis:
              'Distribuição Digital · Direito Brasileiro · Transparência OAB',
          body:
              'As versões Android oficiais do NEXUS DUO são distribuídas com assinatura criptográfica digital e verificação obrigatória SHA-256 contra adulteração. Estes Termos são regidos pelas leis da República Federativa do Brasil. Nota de Governança: este instrumento jurídico completo foi redigido para cobertura técnica e legal multidisciplinar, devendo receber a validação e o preenchimento cadastral definitivo do Controlador (Nome/Razão Social, CPF/CNPJ, endereço e e-mail do Encarregado/DPO) antes de operação comercial em larga escala.',
        ),
      ],
    ),
    LegalDocumentTab(
      id: 'privacy',
      label: 'Privacidade & LGPD',
      subtitle:
          'Política de Privacidade Zero-Trust, Dados Sensíveis, E2EE e Direitos do Titular · Versão $kNexusPrivacyVersion',
      sections: <LegalSection>[
        LegalSection(
          title: '1. Controlador, Encarregado (DPO) e Canal de Contato',
          legalBasis: 'LGPD (Lei nº 13.709/2018, Arts. 5º VI e 41)',
          body:
              'O tratamento dos seus dados pessoais observa rigorosamente os princípios da finalidade, adequação, necessidade, transparência e segurança previstos na LGPD. Solicitações relativas à privacidade, portabilidade, revogação de consentimento ou eliminação podem ser realizadas diretamente no aplicativo (Aba Perfil -> Central de Privacidade & LGPD) e junto ao Encarregado pelo Tratamento de Dados Pessoais (DPO) no canal oficial indicado pelo Controlador.',
        ),
        LegalSection(
          title: '2. Dados Tratados e Dados Pessoais Sensíveis',
          legalBasis: 'LGPD (Arts. 5º I e II, 7º e 11)',
          body:
              'Tratamos: (a) dados cadastrais e de autenticação (e-mail, registro de aceite legal 18+, senha armazenada exclusivamente em hash criptográfico forte no Supabase Auth); (b) dados de perfil gamer (apelido, bio, jogos, horários semanais, DNA gamer, cidade aproximada com fuzzing de ~1 km — nunca exibimos coordenadas exatas); e (c) dados pessoais sensíveis declarados por você com consentimento específico e destacado (gênero e preferências de match). Suas fotos são higienizadas no dispositivo removendo metadados EXIF/GPS antes do envio.',
        ),
        LegalSection(
          title:
              '3. Verificação Facial On-Device (Zero Armazenamento Biométrico)',
          legalBasis: 'LGPD (Arts. 5º II e 11) · Minimização de Dados',
          body:
              'Quando o usuário utiliza a verificação Liveness Anti-Catfish via Google ML Kit, o processamento de detecção facial ocorre 100% localmente no próprio celular. Nenhum template biométrico facial é extraído ou salvo em servidor remoto — apenas o selo booleano de conta verificada é registrado mediante sua confirmação.',
        ),
        LegalSection(
          title: '4. Mensagens E2EE e Sigilo das Comunicações',
          legalBasis:
              'Marco Civil (Art. 7º II e III) · Criptografia X25519 + AES-256-GCM',
          body:
              'As mensagens trocadas nos matches são cifradas ponta a ponta no seu aparelho com troca de chaves X25519, derivação HKDF-SHA256 e cifragem AES-256-GCM antes de chegarem ao banco de dados. Nem administradores do banco nem terceiros conseguem ler o conteúdo das conversas armazenadas. Por essa razão técnica, denúncias de abuso no chat dependem do envio voluntário da mensagem decifrada pelo próprio denunciante.',
        ),
        LegalSection(
          title: '5. Compartilhamento, Transferência Internacional e Retenção',
          legalBasis: 'LGPD (Arts. 15, 16, 33 e 48)',
          body:
              'Jamais vendemos seus dados pessoais. Utilizamos operadores de infraestrutura estritamente necessários sob padrões internacionais de segurança (Supabase/AWS para banco de dados e autenticação isolados e Resend para entrega dos códigos OTP de 6 dígitos por e-mail), configurando transferência internacional nos termos do Art. 33 da LGPD. Códigos OTP expiram em 10 minutos e registros de consentimento/segurança permanecem pelo prazo necessário ao cumprimento de obrigações legais. Incidentes relevantes serão comunicados à ANPD e aos titulares conforme Art. 48.',
        ),
        LegalSection(
          title: '6. Seus Direitos como Titular (Art. 18 da LGPD)',
          legalBasis: 'LGPD (Art. 18, I a IX)',
          body:
              'Você possui pleno direito a confirmar a existência de tratamento, acessar seus dados, corrigir informações, obter portabilidade completa em JSON (botão "Exportar Dados" no Perfil) e solicitar a eliminação definitiva da conta e de todas as suas fotos e registros vinculados (botão "Excluir Conta" via Edge Function segura).',
        ),
      ],
    ),
    LegalDocumentTab(
      id: 'safety',
      label: 'Segurança & Conduta',
      subtitle:
          'Diretrizes Anti-Abuso, Direito Penal Digital, Moderação e Segurança em Encontros Reais',
      sections: <LegalSection>[
        LegalSection(
          title: '1. Tolerância Zero a Crimes Cibernéticos e Violência Digital',
          legalBasis:
              'Código Penal · Leis 12.737/12, 13.718/18, 14.132/21, 14.155/21, 7.716/89, 14.532/23 e 14.811/24',
          body:
              'É terminantemente proibido utilizar o NEXUS DUO para: (a) perseguição reiterada / cyberstalking (Art. 147-A CP); (b) importunação sexual ou divulgação não consensual de cena íntima/nudez (Art. 218-C CP e Art. 21 do Marco Civil — sujeito a remoção imediata); (c) fraude eletrônica, catfishing ou estelionato sentimental (Art. 171 § 2º-A CP); (d) racismo, injúria racial, homofobia/transfobia ou discurso de ódio (Lei 7.716/89 e Lei 14.532/23); (e) intimidação sistemática (cyberbullying, Lei 14.811/24) ou doxxing; e (f) exploração sexual ou qualquer conteúdo envolvendo menores (ECA — reporte imediato às autoridades e SaferNet).',
        ),
        LegalSection(
          title: '2. Proteções Técnicas Integradas (Blur Protetor & Bloqueio)',
          legalBasis: 'Privacy & Safety by Design · Marco Civil Art. 21',
          body:
              'O NEXUS DUO implementa desfoque protetor padrão em mídias enviadas no chat até sua autorização explícita, localização aproximada com ruído aleatório (~1 km) e ferramentas imediatas de Bloqueio e Denúncia. Contas que violem estas diretrizes podem ser suspensas ou banidas definitivamente sem aviso prévio, com preservação das evidências exigidas por ordem judicial ou requisição legal.',
        ),
        LegalSection(
          title: '3. Guia de Segurança para Encontros Presenciais',
          legalBasis:
              'Dever de Cuidado · Responsabilidade Civil (CC Arts. 186 e 927)',
          body:
              'O NEXUS DUO conecta pessoas online e não realiza verificação de antecedentes criminais. Caso decida conhecer alguém presencialmente: (1) mantenha as conversas no chat antes de trocar telefones ou endereços; (2) marque os primeiros encontros exclusivamente em locais públicos e movimentados; (3) informe a um amigo ou familiar com quem estará, o local e o horário previsto; (4) utilize transporte próprio ou de aplicativo; e (5) jamais envie dinheiro, presentes caros, documentos ou códigos de verificação para desconhecidos.',
        ),
      ],
    ),
  ];
}
