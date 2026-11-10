# Roleta — O grande encontro

Aplicativo Windows em Flutter, MobX e Flutter Modular. Os dados ficam em SQLite na pasta de suporte do aplicativo do usuário do Windows (`roleta.sqlite`).

## Uso

1. Na tela inicial, abra Participantes e informe um nome por linha. São necessários pelo menos três nomes únicos.
2. O acesso às configurações fica no canto superior direito. No primeiro acesso, defina uma senha de pelo menos seis caracteres. Nos próximos, informe essa senha.
3. Nas configurações, escolha a sessão, crie sessões independentes e selecione modo normal ou viciado. No modo viciado, adicione combinações direcionais (Ana → Beto). As demais pessoas continuam no sorteio.
4. Salve para validar as regras. Configurações que impedem a conclusão de todos os pares são rejeitadas. Cada pessoa joga uma vez, é sorteada uma vez e nunca tira a si mesma.
5. Na tela principal, entre na roleta, identifique o jogador e gire. A animação termina no resultado efetivamente sorteado.
6. Trocar usuário apresenta as pessoas que ainda não têm uma jogada ativa.
7. Cancelar no histórico preserva o jogador atual, devolve o nome ao sorteio e mantém o registro como cancelado. No modo viciado, a combinação configurada continuará valendo no próximo giro.
8. Só resultados mostra os pares válidos. Exportar CSV salva os resultados ativos da sessão selecionada, com nomes entre aspas e codificação UTF-8.

Após a primeira jogada, participantes e regras ficam bloqueados nessa sessão. Crie outra sessão para uma nova rodada ou outra configuração. Sessões anteriores e seus históricos permanecem disponíveis nas configurações.

O resultado é salvo antes da animação. Se o programa fechar durante o giro, a jogada constará no histórico ao reabrir e poderá ser cancelada. A senha protege o acesso às configurações na interface; não criptografa o banco local. Não há senha padrão. Guarde a senha definida.

## Desenvolvimento

- `flutter pub get`
- `flutter run -d windows`
- `flutter test`
- `flutter build windows --release`

Distribua toda a pasta `build/windows/x64/runner/Release`, incluindo DLLs e dados, não apenas o executável.