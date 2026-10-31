# Capturas de tela

Coloque aqui as imagens citadas no [README principal](../../README.md),
usando exatamente estes nomes de arquivo.

## Aplicativo

| Arquivo | O que registrar |
|---|---|
| `01-login.png` | Tela de login |
| `02-notas.png` | Lista com notas de categorias diferentes e os chips de filtro |
| `03-pesquisa.png` | Um termo digitado na busca e a lista já filtrada |
| `04-formulario.png` | Nota aberta com uma categoria selecionada |
| `05-categorias.png` | Gerenciador de categorias com a contagem de notas |
| `06-lixeira.png` | Lixeira com ao menos uma nota e os botões restaurar/excluir |
| `07-offline.png` | Modo avião ligado: a faixa de aviso e o ícone de nuvem cortada |

## Evidências no Firebase

Console do Firebase, projeto `bdbloco`.

| Arquivo | O que registrar |
|---|---|
| `08-firestore-notas.png` | **Firestore Database** → `users` → seu UID → `notes`, mostrando os documentos |
| `09-firestore-documento.png` | Um documento de nota aberto, com os campos `title`, `content`, `categoryId`, `updatedAt` e `isDeleted` |
| `10-firestore-categorias.png` | A subcoleção `categories` do mesmo usuário |
| `11-authentication.png` | **Authentication** → **Users**, com a conta de teste |
| `12-regras.png` | **Firestore Database** → **Regras**, com as regras deste repositório publicadas |

## Como capturar

- **Emulador Android:** botão da câmera na barra lateral, ou
  `adb exec-out screencap -p > 02-notas.png`.
- **Simulador iOS:** `Cmd + S`, ou
  `xcrun simctl io booted screenshot 02-notas.png`.
- **Console do Firebase:** captura da janela do navegador. Antes de postar,
  confira que a imagem não mostra nada além do projeto de teste.
