# Bloco de Notas

## Objetivo

Aplicativo para criar e organizar notas, mantendo os dados no aparelho com SQLite e sincronizando com o Cloud Firestore. O projeto foi desenvolvido a partir do [código da professora — Turma B](https://github.com/LopesBrendinha/bloco_de_nota_turma_B).

## Funcionalidades

- Cadastro e login com e-mail e senha.
- Criação, consulta, edição e exclusão de notas.
- Seleção de categorias, como Estudos, Trabalho e Pessoal, e criação de categorias no formulário da nota.
- Pesquisa pelo título ou conteúdo.
- Armazenamento local e sincronização com o Firebase.
- Recuperação das notas da nuvem ao entrar em outra instalação.
- Separação das notas por usuário autenticado.

Foram implementadas duas funcionalidades adicionais:

- **Ordenação por data:** permite escolher entre data de criação e última atualização, exibindo as notas da mais recente para a mais antiga.
- **Arquivamento:** permite arquivar uma nota, consultar as notas arquivadas e desarquivá-la mantendo seu conteúdo.

## Tecnologias e dependências

O aplicativo utiliza Flutter e Dart. As dependências estão em `pubspec.yaml`, e as versões resolvidas estão em `pubspec.lock`.

| Dependência | Uso |
| --- | --- |
| `firebase_core` | Inicialização do Firebase. |
| `firebase_auth` | Cadastro, login e encerramento da sessão. |
| `cloud_firestore` | Leitura e gravação das notas na nuvem. |
| `sqflite` | Banco SQLite no aparelho. |
| `path` | Montagem do caminho do arquivo do banco. |
| `cupertino_icons` | Biblioteca de ícones mantida da base. |

Os testes utilizam `flutter_test` e `sqflite_common_ffi`. O `package.json` contém as ferramentas de teste das regras do Firestore; Node.js não é necessário para executar o aplicativo.

## Instalação e execução

A configuração foi preparada para Android. É necessário ter Flutter com Dart compatível com `^3.12.2`, Android SDK e um emulador ou aparelho Android com depuração USB.

Clone a branch do projeto:

```sh
git clone --branch melhorias-bloco-notas https://github.com/andrewbrtl/bloco_de_nota_turma_B.git BlocoDeNotas
cd BlocoDeNotas
flutter doctor
flutter pub get
```

Resolva os problemas de ambiente indicados pelo `flutter doctor`. Se houver licenças do Android pendentes, execute `flutter doctor --android-licenses` e leia os termos apresentados.

### Configuração do Firebase

1. Crie um projeto no [console do Firebase](https://console.firebase.google.com/) ou use um projeto ao qual tenha acesso.
2. Em **Authentication**, habilite o provedor **E-mail/senha**.
3. Em **Firestore Database**, crie o banco padrão `(default)`.
4. Registre um aplicativo Android com o nome de pacote `com.example.blocodenotasturmab`.
5. Baixe o arquivo `google-services.json` desse aplicativo e coloque-o em `android/app/google-services.json`.
6. Na aba **Regras** do Firestore, substitua o conteúdo pelas regras do arquivo `firestore.rules` deste repositório e clique em **Publicar**.

O plugin Google Services já está configurado nos arquivos Gradle. A chamada `Firebase.initializeApp()` usa a configuração Android gerada a partir do JSON. Cada computador precisa receber seu próprio arquivo de configuração, que não é versionado.

Com o Firebase configurado e o emulador ou aparelho conectado:

```sh
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

Substitua `ID_DO_DISPOSITIVO` pelo identificador Android apresentado pelo primeiro comando. Para gerar o APK de depuração:

```sh
flutter build apk --debug
```

O APK fica em `build/app/outputs/flutter-apk/app-debug.apk`. As pastas de outras plataformas foram mantidas da base; esta configuração de execução é para Android. O SQLite utilizado não está configurado para funcionar no navegador.

## Organização do projeto e alterações

A organização mantém a estrutura da professora, com telas, modelo, banco e serviços. As telas usam `StatefulWidget` e `setState` para atualizar a interface.

| Arquivo ou componente | Responsabilidade e alterações |
| --- | --- |
| `lib/main.dart` | Inicializa o Firebase, configura o tema e verifica a sessão para abrir o login ou as notas. |
| `lib/models/note.dart` | Representa a nota. Inclui categoria, identificação local e remota, datas, arquivamento e controle de sincronização. Converte os dados para SQLite e Firestore. |
| `lib/database/database_helper.dart` | Executa as operações no SQLite, a pesquisa, a ordenação e o arquivamento. Também migra o banco anterior preservando as notas. |
| `lib/services/auth_service.dart` | Centraliza cadastro, login e saída pelo Firebase Authentication. |
| `lib/services/firestore_service.dart` | Consulta as notas na nuvem e grava as alterações usando transações. |
| `lib/services/sync_service.dart` | Envia alterações pendentes, recupera notas remotas e trata erros de sincronização. |
| `lib/screens/login_page.dart` e `register_page.dart` | Telas de autenticação e validação dos campos. |
| `lib/screens/notes_page.dart` | Exibe as notas, a pesquisa, a ordenação, o filtro de arquivadas e o estado da sincronização. |
| `lib/screens/note_form_page.dart` | Cria e edita notas, com seleção ou criação de categoria. |
| `lib/widgets/note_card.dart` | Exibe o título, conteúdo, categoria, data e menu de ações da nota. |
| `firestore.rules` | Define as permissões e validações dos documentos na nuvem. |

### Padrões adotados

O `DatabaseHelper` utiliza **Singleton**, por meio de `DatabaseHelper.instance`, para compartilhar uma instância de acesso ao banco entre as telas.

Os serviços separam as operações de autenticação e sincronização da interface. O modelo `Note` concentra os campos da nota e sua conversão para os dois bancos. Essa separação mantém o acesso aos dados fora do código de apresentação das telas.

## Armazenamento e sincronização

As telas consultam o SQLite. Ao criar, editar, arquivar ou excluir uma nota, a alteração é salva primeiro no aparelho e marcada como pendente de sincronização pelo campo `pendingSync`.

Cada nota tem um identificador local e um `remoteId`, utilizado no Firestore. Os documentos ficam no caminho:

```text
users/{uid}/notes/{remoteId}
```

A sincronização ocorre ao abrir a tela de notas, voltar ao aplicativo, retornar do formulário, realizar ações sobre as notas ou tocar no botão de sincronizar.

1. O serviço busca as alterações pendentes do usuário no SQLite.
2. Envia cada alteração ao Firestore e retira a pendência após a confirmação do servidor.
3. Consulta as notas do usuário na nuvem e atualiza o banco local. Isso permite recuperar as notas em outra instalação.

Se a mesma nota for editada em dois aparelhos, prevalece a versão com maior data de atualização. Em empate, permanece a versão da nuvem. Essa comparação depende do relógio dos aparelhos. Uma edição feita durante um envio permanece pendente para a próxima sincronização.

A exclusão apaga o título, conteúdo e categoria, mantendo um registro marcado como excluído para comunicar a operação aos outros aparelhos. A exclusão prevalece sobre edições antigas e não oferece recuperação. O arquivamento mantém o conteúdo e permite devolver a nota à lista principal.

A pesquisa compara o texto informado com o título e o conteúdo das notas locais, incluindo as recuperadas da nuvem, sem diferenciar maiúsculas e minúsculas. As categorias personalizadas são armazenadas junto com as notas e ficam disponíveis após salvar uma nota com a categoria.

### Tratamento de erros

Quando não há conexão ou o Firebase não responde, as alterações continuam no SQLite e a tela informa a falha. Depois de recuperar a conexão, o usuário pode tocar em **Sincronizar** ou reabrir o aplicativo.

Se uma nota for recusada por dados inválidos ou falta de permissão, ela permanece pendente, enquanto as demais podem ser sincronizadas. A interface informa a sincronização parcial. Pedidos feitos durante um envio são retomados após a tentativa atual.

## Autenticação e segurança

O Firebase Authentication identifica cada usuário pelo UID. As consultas locais usam esse identificador, e as regras do Firestore permitem acesso apenas ao usuário autenticado que corresponde ao dono do caminho `users/{uid}/notes`.

As regras também validam os campos e impedem a alteração do dono e da data de criação. Elas precisam estar publicadas no projeto Firebase utilizado para executar o aplicativo.

O cadastro e um novo login precisam de internet. Uma sessão já salva permite acessar as notas locais sem conexão. Alterações ainda não sincronizadas dependem dos dados armazenados naquele aparelho.

Arquivos de configuração local e credenciais são ignorados pelo Git. Não devem ser incluídos senhas, chaves privadas, tokens ou arquivos de conta de serviço. Manter o JSON fora do repositório não substitui as regras de acesso do Firestore.

## Testes

Para executar a análise e os testes do aplicativo:

```sh
flutter analyze
flutter test
```

Os testes verificam operações nas notas, categorias, pesquisa, ordenação, arquivamento, migração do banco, isolamento por usuário e situações de falha na sincronização. Utilizam SQLite em arquivos temporários e uma conexão remota simulada.

Para testar as regras do Firestore, com Node.js compatível com as dependências e Java 21 instalados:

```sh
npm ci
npm run test:rules
```

Esses testes usam o emulador oficial do Firestore com um projeto fictício. Verificam as permissões por usuário e a validação dos documentos.

## Capturas de tela

As capturas do aplicativo, incluindo ordenação por data e arquivamento, e as evidências das notas armazenadas no Firebase serão enviadas separadamente no Google Classroom, junto com os links do fork e do Pull Request.
