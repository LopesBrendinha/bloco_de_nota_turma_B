# Validação do aplicativo

Validação realizada em 02/11/2026, com Flutter 3.47.6 e Dart 3.13.5 no Windows, usando Chrome e SQLite persistente no navegador.

## Resultado dos testes

| Verificação | Resultado |
| --- | --- |
| Testes Dart do SQLite e sincronização | 10 testes aprovados |
| Regras de segurança no Firestore Emulator | 4 grupos de testes aprovados |
| Aplicativo completo no Chrome com Firebase Emulator | Aprovado |
| Aplicativo completo no Chrome com Firebase real | Aprovado |
| `flutter analyze` | Sem problemas encontrados |
| `flutter build web` com configuração do Firebase real | Gerado com sucesso |
| `flutter build apk --debug` com configuração Android do Firebase real | APK gerado com sucesso |

O teste da nuvem usou o projeto **bloco-de-notas-544ec**, banco `(default)`, região `southamerica-east1`, plano Spark. As regras deste repositório foram publicadas nesse projeto pelo Firebase CLI.

No teste real, o aplicativo criou a conta de validação, gravou uma nota pelo SQLite, enviou ao Firestore e consultou o documento com `Source.server`. Em seguida, pesquisou por conteúdo sem acento, arquivou e desarquivou a nota, abriu um segundo arquivo SQLite vazio e recuperou os dados da nuvem.

Para o cenário de falha, o teste interrompeu temporariamente as chamadas pela interface `NotesCloud`, retornando `unavailable`. A edição continuou salva e pendente no SQLite. Depois de liberar a comunicação, o app enviou a alteração ao Firestore e confirmou o texto atualizado no servidor. Essa falha é simulada no serviço; a rede do computador não é desligada.

Também foram testados saída e nova entrada na conta, criação e exclusão de uma nota temporária e remoção do título e do conteúdo no marcador de exclusão do Firestore. Uma segunda instância do Firebase, com outra conta autenticada, recebeu `permission-denied` ao tentar consultar e alterar a nota da primeira. A leitura sem autenticação também foi negada.

## Documento da validação final

```text
users/sLd4dFL96QMTEXeHo3HaIMf9dHl2/notes/33785f52-f788-4ce7-b9fc-a58323adf0b6
```

O identificador acima pertence à conta de teste e permite localizar a nota no console do projeto. O conteúdo final é “Revisão concluída”, na categoria Faculdade. As capturas de criação, pesquisa e arquivamento mostram etapas anteriores da mesma execução, antes da edição final.

- [Documento no Firestore](screenshots/firebase-documento.png)
- [Regras publicadas](screenshots/firebase-regras.png)
- [Listagem com nota sincronizada](screenshots/nuvem-notas.png)
- [Editor e categoria criada](screenshots/nuvem-editor.png)
- [Pesquisa pelo conteúdo](screenshots/nuvem-pesquisa.png)
- [Nota arquivada](screenshots/nuvem-arquivo.png)
- [Alteração pendente após falha simulada](screenshots/nuvem-pendente.png)
- [Estado final, após nova entrada e sincronização](screenshots/nuvem-final.png)

As imagens `firebase-*.png` são capturas do console do Firebase. As imagens `nuvem-*.png` são capturas do app executado com o Firebase real. As imagens `emulador-*.png` registram a execução local com os emuladores e não são evidência de armazenamento em nuvem.

## Repetir a avaliação manual

1. Configure seu Firebase como descrito no README e publique as regras.
2. Entre em uma conta, crie uma nota com uma categoria nova e espere a indicação “Sincronizada”.
3. Confira o documento em `users/{uid}/notes` no console do Firestore.
4. Pesquise uma palavra do título e outra que apareça apenas no conteúdo. Teste também acentos e maiúsculas.
5. Edite a nota, confira a alteração no console, arquive e desarquive.
6. Interrompa a conexão do dispositivo, altere uma nota e confira que ela continua acessível e pendente. Restabeleça a conexão e sincronize.
7. Saia e entre novamente. Abra o app em outro navegador ou instalação, com armazenamento local vazio, usando a mesma conta; as notas devem ser recuperadas.
8. Entre em outra conta: as notas anteriores não devem aparecer. As tentativas diretas de acesso ao caminho de outra conta devem ser negadas pelas regras.
9. Exclua uma nota de teste e sincronize. O conteúdo deve desaparecer das consultas, com um marcador `deleted = true` e texto vazio no Firestore.

Limites: não houve execução em aparelho Android físico ou iPhone. O teste de outra instalação usa um segundo arquivo SQLite vazio com a mesma conta, e o teste de novo login sai e entra novamente no aplicativo. Testes com relógios de aparelhos diferentes exigem considerar a política de conflito por `updatedAt`, descrita no README.
