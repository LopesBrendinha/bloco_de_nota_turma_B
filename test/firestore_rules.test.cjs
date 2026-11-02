const { readFileSync } = require('node:fs');
const { before, after, beforeEach, test } = require('node:test');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, collection, setDoc, getDoc, getDocs, updateDoc, deleteDoc } = require('firebase/firestore');

let environment;
const note = {
  uid: 'ana', title: 'Prova', content: 'Revisar matemática', category: 'Estudos',
  createdAt: 100, updatedAt: 100, archived: false, deleted: false,
};
const reference = (user = 'ana', owner = 'ana') =>
  doc(environment.authenticatedContext(user).firestore(), `users/${owner}/notes/nota-1`);

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-bloco-notas',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
beforeEach(async () => { await environment.clearFirestore(); });
after(async () => { if (environment) await environment.cleanup(); });

test('dono pode cadastrar, consultar, editar, arquivar e excluir o conteúdo', async () => {
  const ref = reference();
  await assertSucceeds(setDoc(ref, note));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(getDocs(collection(environment.authenticatedContext('ana').firestore(), 'users/ana/notes')));
  await assertSucceeds(updateDoc(ref, { content: 'Revisado', updatedAt: 200 }));
  await assertSucceeds(updateDoc(ref, { archived: true, updatedAt: 300 }));
  await assertSucceeds(updateDoc(ref, { archived: false, updatedAt: 400 }));
  await assertSucceeds(updateDoc(ref, {
    title: '', content: '', category: '', archived: false, deleted: true, updatedAt: 500,
  }));
  await assertFails(updateDoc(ref, { ...note, updatedAt: 600 }));
});

test('outro usuário não lê, lista, cria, altera ou apaga notas do dono', async () => {
  await setDoc(reference(), note);
  const ref = reference('bia');
  await assertFails(getDoc(ref));
  await assertFails(getDocs(collection(environment.authenticatedContext('bia').firestore(), 'users/ana/notes')));
  await assertFails(setDoc(ref, note));
  await assertFails(updateDoc(ref, { title: 'Alterado' }));
  await assertFails(deleteDoc(ref));
  await assertFails(setDoc(doc(environment.authenticatedContext('bia').firestore(), 'users/ana/notes/nova'), note));
});

test('sem autenticação não acessa notas', async () => {
  await setDoc(reference(), note);
  const ref = doc(environment.unauthenticatedContext().firestore(), 'users/ana/notes/nota-1');
  await assertFails(getDoc(ref));
  await assertFails(setDoc(ref, note));
  await assertFails(deleteDoc(ref));
});

test('valida dono, campos, datas e marca de exclusão', async () => {
  const ref = reference();
  await assertFails(setDoc(ref, { ...note, uid: 'bia' }));
  await assertFails(setDoc(ref, { ...note, content: '' }));
  await assertFails(setDoc(ref, { ...note, archived: 'sim' }));
  await assertFails(setDoc(ref, { ...note, extra: 'campo desconhecido' }));
  await assertFails(setDoc(ref, { ...note, updatedAt: 50 }));
  await assertFails(setDoc(ref, { ...note, deleted: true }));
  await setDoc(ref, note);
  await assertFails(updateDoc(ref, { createdAt: 50 }));
  await assertFails(deleteDoc(ref));
});
