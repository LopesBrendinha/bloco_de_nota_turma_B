Capturas que faltam produzir

Use o aplicativo conectado ao seu projeto Firebase. Não há capturas de uma conta real nesta pasta.

1. Entre com uma conta e crie uma nota na categoria Estudos. Aguarde “Notas sincronizadas”. Capture a listagem como 01-notas.png.
2. Pesquise parte do título e depois parte do conteúdo. Capture um resultado como 02-pesquisa.png.
3. Edite a nota, crie uma categoria e salve. Capture a edição como 03-categoria.png.
4. Crie outra nota e depois edite a primeira. Selecione data de criação e capture como 04a-ordenacao-criacao.png. Selecione última atualização e capture como 04b-ordenacao-atualizacao.png. As duas capturas devem mostrar a mudança de ordem das mesmas notas.
5. Arquive uma nota pelo menu do cartão. Abra o filtro Arquivadas e capture como 05a-arquivadas.png. Desarquive a nota, volte à lista principal e capture como 05b-desarquivada.png, mostrando que o conteúdo foi mantido.
6. No console Firebase, abra Firestore Database → Dados → users → seu UID → notes. Selecione o documento e mostre título, conteúdo, categoria e datas. Capture como 06-firestore.png. O documento pai do UID pode aparecer sem campos; os dados estão na subcoleção notes.
7. Desconecte a internet, crie e edite uma nota. Confira que ela continua visível no app. Reconecte, use Sincronizar e confira o documento no console. Capture a mensagem de falha e o resultado sincronizado como 07-sem-conexao.png e 08-sincronizado.png.
8. Com tudo sincronizado, entre com a mesma conta em outro aparelho ou em uma instalação limpa e confira as notas recuperadas. Capture como 09-recuperacao.png.
9. Entre com outra conta e confira que as notas anteriores não aparecem. Faça uma captura como 10-outra-conta.png.
10. Exclua uma nota, sincronize e confira no Firestore que ela ficou com deleted = true e conteúdo vazio. Confira que não aparece no outro aparelho após sincronizar. Capture como 11-exclusao.png.

Evite capturar senhas ou informações pessoais. Não desinstale antes de sincronizar as pendências locais.

Depois liste no README.md principal os caminhos das capturas que produziu, por exemplo:

Notas no aplicativo: docs/evidencias/01-notas.png
Pesquisa: docs/evidencias/02-pesquisa.png
Categoria: docs/evidencias/03-categoria.png
Ordenação por criação: docs/evidencias/04a-ordenacao-criacao.png
Ordenação por atualização: docs/evidencias/04b-ordenacao-atualizacao.png
Nota arquivada: docs/evidencias/05a-arquivadas.png
Nota desarquivada: docs/evidencias/05b-desarquivada.png
Documento no Firestore: docs/evidencias/06-firestore.png
Falha de conexão: docs/evidencias/07-sem-conexao.png
Nota sincronizada: docs/evidencias/08-sincronizado.png
Notas recuperadas: docs/evidencias/09-recuperacao.png
Outra conta: docs/evidencias/10-outra-conta.png
Exclusão sincronizada: docs/evidencias/11-exclusao.png

Acrescente uma legenda curta com o que cada captura comprova. Remova do README a indicação de pendência somente depois de salvar e conferir as imagens na pasta de evidências.
