# Bloco de Notas

Aplicativo de notas desenvolvido em Flutter. As notas ficam salvas em um banco local (SQLite) e também na nuvem (Cloud Firestore), cada uma ligada ao usuário autenticado com o Firebase Authentication.

## Funcionalidades implementadas

- Cadastro, login e logout com e-mail e senha (Firebase Authentication).
- Criar, consultar, editar e excluir notas, tanto no banco local quanto no Firebase.
- Cada nota pertence ao usuário autenticado (campo `uid`).
- Recuperação das notas da nuvem ao entrar novamente ou em outra instalação.
- Tratamento de erros de conexão com o Firebase.
- Regras de segurança do Firestore: cada usuário acessa só as próprias notas.
- Categorias (Geral, Estudos, Trabalho e Pessoal): escolha na criação/edição da nota, exibição no cartão e filtro na lista.
- Pesquisa de notas por título ou conteúdo.
- **Funcionalidade adicional: ordenação por data**, por criação ou por última atualização.

## Tecnologias e dependências

- Flutter e Dart (versão do SDK definida no `pubspec.yaml`)
- `firebase_core` e `firebase_auth`: inicialização do Firebase e autenticação
- `cloud_firestore`: armazenamento das notas na nuvem
- `sqflite`: banco de dados local
- `sqflite_common_ffi_web`: permite usar o SQLite no navegador
- `path`: montagem do caminho do arquivo do banco

As versões exatas estão no `pubspec.yaml`.

## Como instalar e executar

1. Instale o [Flutter](https://docs.flutter.dev/get-started/install).
2. Clone o repositório e entre na pasta do projeto.
3. Instale as dependências:
   ```bash
   flutter pub get
   ```
4. Configure o Firebase (próxima seção). Os arquivos de configuração **não estão no repositório**.
5. Se a pasta `web/` não tiver os arquivos `sqlite3.wasm` e `sqflite_sw.js`, gere-os:
   ```bash
   dart run sqflite_common_ffi_web:setup
   ```
6. Execute no navegador, sempre na mesma porta (o banco local do navegador depende da porta):
   ```bash
   flutter run -d chrome --web-port 8080
   ```

O aplicativo foi testado no Chrome. O projeto também tem configuração para Android e iOS, mas esses alvos não foram testados.

## Como configurar o Firebase

Os arquivos `lib/firebase_options.dart` e `android/app/google-services.json` não são versionados, porque contêm dados específicos do projeto Firebase. Para gerá-los:

1. No [console do Firebase](https://console.firebase.google.com), crie um projeto.
2. Em **Authentication > Método de login**, ative **E-mail/senha**.
3. Em **Firestore Database**, crie um banco de dados.
4. Em **Firestore Database > Regras**, publique as regras da seção de segurança abaixo.
5. Instale as ferramentas e conecte o app ao seu projeto:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Escolha o seu projeto e as plataformas desejadas. Ao perguntar se deseja reaproveitar o `firebase.json` existente, responda **não**. O comando gera o `lib/firebase_options.dart`.

## Arquitetura e organização dos arquivos

```
lib/
├── main.dart                      # Inicializa o Firebase e o SQLite (web) e abre o app
├── firebase_options.dart          # Gerado pelo flutterfire configure (não versionado)
├── models/
│   ├── note.dart                  # Modelo Note (conversão de/para Map)
│   └── categories.dart            # Lista das categorias disponíveis
├── database/
│   └── database_helper.dart       # Acesso ao SQLite (criar tabela, CRUD, pesquisa)
├── services/
│   ├── auth_service.dart          # Login, cadastro e logout (Firebase Auth)
│   ├── firestore_service.dart     # Leitura e escrita das notas no Firestore
│   └── note_repository.dart       # Une SQLite e Firestore e faz a sincronização
├── screens/
│   ├── login_page.dart            # Tela de login
│   ├── register_page.dart         # Tela de cadastro
│   ├── notes_page.dart            # Lista, pesquisa, filtro de categoria e ordenação
│   └── note_form_page.dart        # Criação e edição de nota
└── widgets/
    └── note_card.dart             # Cartão de nota exibido na lista
```

As telas conversam com o `NoteRepository`, que decide quando usar o banco local e quando usar o Firestore. As telas não acessam o SQLite nem o Firestore diretamente.

## Padrões de projeto

- **Singleton** (`DatabaseHelper.instance`): garante uma única instância e uma única conexão com o banco local em todo o app.
- **Repository** (`NoteRepository`): concentra a regra de salvar, excluir, buscar e sincronizar, escondendo das telas a existência de dois armazenamentos. Se a estratégia de sincronização mudar, só essa classe muda.
- **Camada de serviços** (`AuthService`, `FirestoreService`): isola o acesso ao Firebase em classes próprias, em vez de espalhá-lo pelas telas.

## Armazenamento local e integração com o Firebase

**Local (SQLite):** a tabela `notes` guarda `id`, `uid`, `title`, `content`, `date`, `category`, `createdAt` e `updatedAt`. Quando a estrutura mudou, foi criada uma migração (`onUpgrade`) para não perder dados de bancos antigos. No navegador, o banco fica no IndexedDB, por meio do `sqflite_common_ffi_web`.

**Nuvem (Firestore):** cada nota é um documento em `usuarios/{uid}/notas/{id}`, com os mesmos campos da tabela local.

**Identificador:** o `id` da nota é a hora de criação em milissegundos. Assim o mesmo id é usado nos dois armazenamentos e não se repete entre instalações diferentes do mesmo usuário.

## Estratégia de sincronização e tratamento de erros

**Gravação (criar, editar, excluir):** a operação é feita primeiro no SQLite e depois enviada ao Firestore. O app nunca perde a nota por causa de falha de rede.

**Sincronização:** ao abrir a lista, o app mostra as notas locais e em seguida compara com as do Firestore:
- Nota que só existe em um dos lados é copiada para o outro.
- Nota que existe nos dois lados com conteúdo diferente: vale a de `updatedAt` mais recente.

Assim, ao entrar de novo ou usar outra instalação, as notas da nuvem são recuperadas para o banco local.

**Erros de conexão:** as chamadas ao Firestore têm limite de 5 segundos e ficam dentro de `try/catch`. Se falharem, a nota continua salva localmente e o app mostra uma mensagem avisando que ela não foi enviada ao Firebase. O envio é tentado de novo na próxima sincronização.

**Limitações conhecidas:**
- Se uma nota for excluída com o app offline, ela volta na próxima sincronização, porque ainda existe na nuvem.
- A pesquisa usa `LIKE` do SQLite: ignora maiúsculas/minúsculas apenas em letras sem acento.
- A sincronização acontece ao abrir a lista, não em tempo real.
- No navegador, o banco local depende da porta usada (`localhost:8080` e `localhost:8081` têm bancos diferentes).

## Autenticação e segurança dos dados

- O login é feito com e-mail e senha pelo Firebase Authentication. O `uid` do usuário é gravado em cada nota.
- No banco local, todas as consultas filtram por `uid`.
- No Firestore, as notas ficam dentro do caminho do próprio usuário e as regras abaixo impedem que um usuário leia ou altere as notas de outro:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /usuarios/{uid}/notas/{notaId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

- Nenhuma senha ou arquivo de credenciais é versionado: `lib/firebase_options.dart` e `android/app/google-services.json` estão no `.gitignore`.

## Capturas de tela

### Aplicativo

| Login | Lista de notas |
|---|---|
| ![Login](docs/prints/01-login.png) | ![Lista](docs/prints/02-lista-notas.png) |

| Formulário com categoria | Pesquisa |
|---|---|
| ![Formulário](docs/prints/03-formulario.png) | ![Pesquisa](docs/prints/04-pesquisa.png) |

| Ordenação por atualização | Erro de conexão |
|---|---|
| ![Ordenação](docs/prints/05-ordenacao.png) | ![Offline](docs/prints/06-erro-offline.png) |

### Evidências no Firebase

**Usuários cadastrados (Authentication):**

![Authentication](docs/prints/07-firebase-auth.png)

**Notas armazenadas no Firestore:**

![Firestore](docs/prints/08-firestore-notas.png)

**Regras de segurança publicadas:**

![Regras](docs/prints/09-firestore-regras.png)