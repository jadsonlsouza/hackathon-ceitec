<script setup lang="ts">
import BrandLogo from '../brand/BrandLogo.vue'

const stages = [
  { number: '01', title: 'Organize o evento', text: 'Defina atividades, categorias e critérios de avaliação para cada hackathon.' },
  { number: '02', title: 'Acompanhe as equipes', text: 'Reúna participantes, entregas e feedbacks no mesmo espaço.' },
  { number: '03', title: 'Avalie e publique', text: 'Registre notas por critério e publique os resultados por categoria.' },
]

const roles = [
  { name: 'Alunos', detail: 'Criam equipes e desenvolvem suas atividades.' },
  { name: 'Professores', detail: 'Organizam o evento e acompanham as entregas.' },
  { name: 'Monitores', detail: 'Revisam os envios e podem enviar feedback.' },
  { name: 'Avaliadores', detail: 'Atribuem notas conforme os critérios do evento.' },
  { name: 'Administradores', detail: 'Gerenciam eventos, pessoas e permissões.' },
]
</script>

<template>
  <div class="liga-home">
    <a class="liga-skip" href="#conteudo-principal">Pular para o conteúdo</a>
    <header class="liga-nav">
      <NuxtLink to="/" aria-label="Ligalab, página inicial" class="liga-nav__brand"><BrandLogo variant="dark" /></NuxtLink>
      <nav aria-label="Navegação principal" class="liga-nav__links">
        <a href="#como-funciona">Como funciona</a>
        <a href="#perfis">Para quem</a>
        <NuxtLink to="/eventos">Eventos</NuxtLink>
      </nav>
      <div class="liga-nav__actions">
        <NuxtLink to="/login" class="liga-nav__login">Entrar</NuxtLink>
        <NuxtLink to="/cadastro" class="liga-button liga-button--small">Criar conta <span aria-hidden="true">↗</span></NuxtLink>
      </div>
    </header>

    <main id="conteudo-principal" tabindex="-1">
      <section class="liga-hero" data-enter>
        <div class="liga-hero__inner">
          <div class="liga-hero__copy">
            <p class="liga-kicker"><span /> Plataforma de eventos e aprendizagem</p>
            <h1>Grandes ideias começam <em>em equipe.</em></h1>
            <p class="liga-hero__lead">Do primeiro encontro à apresentação final: organize hackathons, acompanhe projetos e conecte as pessoas que fazem tudo acontecer.</p>
            <div class="liga-actions">
              <NuxtLink to="/eventos" class="liga-button">Ver eventos <span aria-hidden="true">↗</span></NuxtLink>
              <a href="#como-funciona" class="liga-text-link">Conheça a plataforma <span aria-hidden="true">↓</span></a>
            </div>
          </div>
          <div class="liga-workspace" aria-label="Recursos do Ligalab">
            <div class="liga-workspace__top"><span class="liga-workspace__mark">L.</span><span>Área de trabalho</span><span class="liga-workspace__dots" aria-hidden="true">•••</span></div>
            <div class="liga-workspace__body">
              <div class="liga-workspace__side" aria-hidden="true"><span class="is-active" /><span /><span /><span /></div>
              <div class="liga-workspace__main">
                <p class="liga-workspace__eyebrow">SEU EVENTO, EM UM SÓ LUGAR</p>
                <h2>Das ideias<br>às entregas.</h2>
                <div class="liga-workspace__cards">
                  <div><span class="liga-card-icon">↗</span><strong>Equipes</strong><small>Organize participantes</small></div>
                  <div><span class="liga-card-icon">✳</span><strong>Atividades</strong><small>Construa e envie projetos</small></div>
                  <div><span class="liga-card-icon">✓</span><strong>Avaliação</strong><small>Acompanhe os resultados</small></div>
                </div>
                <div class="liga-workspace__line"><span>Seu próximo projeto começa aqui</span><span aria-hidden="true">↗</span></div>
              </div>
            </div>
          </div>
        </div>
        <div class="liga-hero__bottom"><span>IDEIAS + PESSOAS + AÇÃO</span><span>FEITO PARA APRENDER JUNTO ↓</span></div>
      </section>

      <section id="como-funciona" class="liga-section liga-process">
        <div class="liga-section__heading"><p class="liga-kicker">01 / COMO FUNCIONA</p><h2>Uma plataforma.<br><em>Todo o percurso.</em></h2><p>Mais tempo para criar, colaborar e aprender. As etapas do evento ficam organizadas em um só lugar.</p></div>
        <div class="liga-stages"><article v-for="stage in stages" :key="stage.number" class="liga-stage"><span class="liga-stage__number">{{ stage.number }} /</span><div><h3>{{ stage.title }}</h3><p>{{ stage.text }}</p></div><span class="liga-stage__arrow" aria-hidden="true">↗</span></article></div>
      </section>

      <section class="liga-feature">
        <div class="liga-feature__content"><p class="liga-kicker">02 / TRABALHO EM EQUIPE</p><h2>O espaço onde<br><em>as ideias ganham forma.</em></h2><p>Professores criam atividades em canvas. Equipes trabalham nas respostas, enviam suas entregas e acompanham o retorno da organização.</p><NuxtLink to="/cadastro" class="liga-button liga-button--light">Criar conta <span aria-hidden="true">↗</span></NuxtLink></div>
        <div class="liga-feature__canvas" aria-label="Exemplo de organização de uma atividade"><div class="liga-canvas__head"><span>ATIVIDADE / CANVAS</span><span>● EM ANDAMENTO</span></div><div class="liga-canvas__title">Construindo uma ideia<span>✳</span></div><div class="liga-canvas__row"><span>01</span><strong>Qual desafio queremos resolver?</strong><span>↗</span></div><div class="liga-canvas__row"><span>02</span><strong>Como nossa equipe pode ajudar?</strong><span>↗</span></div><div class="liga-canvas__row"><span>03</span><strong>O que vamos apresentar?</strong><span>↗</span></div></div>
      </section>

      <section id="perfis" class="liga-section liga-roles">
        <div class="liga-section__heading"><p class="liga-kicker">03 / PESSOAS</p><h2>Cada pessoa tem<br><em>um papel importante.</em></h2><p>Uma experiência para quem participa, acompanha, organiza e avalia.</p></div>
        <div class="liga-roles__list"><article v-for="(role, index) in roles" :key="role.name"><span class="liga-roles__index">0{{ index + 1 }}</span><h3>{{ role.name }}</h3><p>{{ role.detail }}</p><span aria-hidden="true">↗</span></article></div>
      </section>

      <section class="liga-final"><p class="liga-kicker">O PRÓXIMO PASSO É SEU</p><h2>Vamos tirar ideias<br><em>do papel?</em></h2><p>Encontre um evento e participe com sua equipe.</p><NuxtLink to="/eventos" class="liga-button liga-button--light">Ver eventos <span aria-hidden="true">↗</span></NuxtLink></section>
    </main>

    <footer class="liga-footer"><BrandLogo variant="dark" /><p>Uma plataforma para aprender, criar e colaborar.</p><nav aria-label="Links do rodapé"><NuxtLink to="/eventos">Eventos</NuxtLink><NuxtLink to="/login">Entrar</NuxtLink><NuxtLink to="/cadastro">Criar conta</NuxtLink></nav><span>© {{ new Date().getFullYear() }} Ligalab</span></footer>
  </div>
</template>

<style scoped>
.liga-home{--blue:#43c8fa;--ink:#08111f;--paper:#f4f7f8;background:#08111f;color:#f4f8fc;font-family:Inter,ui-sans-serif,system-ui,sans-serif}.liga-home *{box-sizing:border-box}.liga-home a{text-decoration:none}.liga-skip{background:white;color:#08111f;left:1rem;padding:.8rem;position:absolute;top:-5rem;z-index:100}.liga-skip:focus{top:1rem}.liga-nav{align-items:center;border-bottom:1px solid #ffffff1a;display:flex;gap:2rem;height:82px;margin:auto;max-width:1440px;padding:0 clamp(1.25rem,5vw,5rem)}.liga-nav__brand{margin-right:auto;width:145px}.liga-nav__brand :deep(img){width:100%}.liga-nav__links,.liga-nav__actions{align-items:center;display:flex;gap:2rem}.liga-nav__links a,.liga-nav__login{color:#bcc9d5;font-size:.85rem;font-weight:650}.liga-nav__links a:hover,.liga-nav__login:hover{color:#fff}.liga-nav__actions{gap:1.5rem}.liga-button{align-items:center;background:#53d0fc;border:1px solid #53d0fc;border-radius:.35rem;color:#071523;display:inline-flex;font-size:.92rem;font-weight:750;gap:2.5rem;justify-content:space-between;min-height:54px;padding:.85rem 1.1rem;transition:transform .18s,background .18s}.liga-button:hover{background:#9de5ff;transform:translateY(-2px)}.liga-button:active{transform:translateY(0)}.liga-button--small{font-size:.8rem;min-height:42px;padding:.65rem .9rem}.liga-button--light{background:#f6fbfd;border-color:#f6fbfd}.liga-hero{background:radial-gradient(ellipse at 70% 45%,#123e5b 0%,#0a1828 45%,#08111f 75%);min-height:calc(100vh - 82px);position:relative}.liga-hero__inner{align-items:center;display:grid;gap:clamp(2rem,5vw,6rem);grid-template-columns:1fr 1fr;margin:auto;max-width:1440px;min-height:calc(100vh - 130px);padding:4rem clamp(1.25rem,5vw,5rem)}.liga-kicker{align-items:center;color:#66d4fb;display:flex;font-size:.7rem;font-weight:800;gap:.65rem;letter-spacing:.12em;margin:0 0 1.6rem;text-transform:uppercase}.liga-kicker span{background:#53d0fc;border-radius:50%;height:7px;width:7px}.liga-hero h1,.liga-section h2,.liga-feature h2,.liga-final h2{font-size:clamp(3.2rem,6.5vw,6.7rem);font-weight:650;letter-spacing:-.065em;line-height:1;margin:0}.liga-home h1 em,.liga-home h2 em{color:#61d3fa;font-style:normal}.liga-hero__lead,.liga-feature__content>p:not(.liga-kicker){color:#b2c2cf;font-size:clamp(1rem,1.3vw,1.2rem);line-height:1.65;margin:1.75rem 0 2rem;max-width:34rem}.liga-actions{align-items:center;display:flex;flex-wrap:wrap;gap:1.75rem}.liga-text-link{color:#d7e5ee;font-size:.88rem;font-weight:650}.liga-text-link span{margin-left:.7rem}.liga-hero__bottom{border-top:1px solid #ffffff1a;color:#91a5b5;display:flex;font-size:.64rem;font-weight:700;justify-content:space-between;letter-spacing:.12em;margin:0 auto;max-width:1280px;padding:1.25rem 0}.liga-workspace{background:#eaf2f6;border:7px solid #243c51;border-radius:1rem;box-shadow:0 35px 100px #0008;color:#0a1c2b;overflow:hidden}.liga-workspace__top{align-items:center;background:#f9fcfd;border-bottom:1px solid #d9e5ea;display:flex;font-size:.75rem;font-weight:750;gap:.7rem;padding:.8rem 1rem}.liga-workspace__mark{align-items:center;background:#007bad;border-radius:.3rem;color:white;display:flex;font-weight:900;height:25px;justify-content:center;width:25px}.liga-workspace__dots{color:#78909e;font-size:1rem;letter-spacing:.1em;margin-left:auto}.liga-workspace__body{display:flex;min-height:330px}.liga-workspace__side{background:#10283a;display:grid;align-content:start;gap:1.1rem;padding:1.4rem 1rem}.liga-workspace__side span{background:#648094;border-radius:.2rem;height:12px;opacity:.6;width:12px}.liga-workspace__side .is-active{background:#4acafa;opacity:1}.liga-workspace__main{flex:1;padding:clamp(1.2rem,3vw,2.3rem)}.liga-workspace__eyebrow{color:#0879a4;font-size:.6rem;font-weight:800;letter-spacing:.08em}.liga-workspace h2{font-size:clamp(1.7rem,2.8vw,2.8rem);letter-spacing:-.05em;line-height:1.04;margin:.7rem 0 1.6rem}.liga-workspace__cards{display:grid;gap:.5rem;grid-template-columns:repeat(3,minmax(0,1fr))}.liga-workspace__cards>div{background:white;border:1px solid #dbe6eb;border-radius:.5rem;display:grid;gap:.35rem;padding:.8rem}.liga-card-icon{color:#087fab;font-size:1.3rem}.liga-workspace__cards strong{font-size:.72rem}.liga-workspace__cards small{color:#69808c;font-size:.6rem;line-height:1.4}.liga-workspace__line{border-top:1px solid #cfdee4;color:#68808d;display:flex;font-size:.65rem;justify-content:space-between;margin-top:1.4rem;padding-top:1rem}.liga-section{padding:clamp(5rem,9vw,9rem) max(1.25rem,calc((100vw - 1280px)/2))}.liga-process,.liga-roles{background:#f4f7f8;color:#102132}.liga-section__heading{display:grid;gap:1.5rem;grid-template-columns:1fr 1fr;align-items:end}.liga-section__heading .liga-kicker{grid-column:1/-1;margin:0;color:#087fae}.liga-section h2,.liga-feature h2{font-size:clamp(2.7rem,5vw,5rem)}.liga-section h2 em{color:#057eaf}.liga-section__heading>p:last-child{color:#627382;line-height:1.65;margin:0;max-width:24rem}.liga-stages{border-top:1px solid #bfcdd4;display:grid;grid-template-columns:repeat(3,1fr);margin-top:5rem}.liga-stage{border-right:1px solid #cdd9de;display:flex;flex-direction:column;min-height:240px;padding:1.5rem 1.5rem 0 0}.liga-stage+.liga-stage{padding-left:1.5rem}.liga-stage:last-child{border:0}.liga-stage__number,.liga-roles__index{color:#0784b2;font-size:.72rem;font-weight:800}.liga-stage h3{font-size:1.45rem;letter-spacing:-.03em;margin:3.2rem 0 .6rem}.liga-stage p,.liga-roles__list p{color:#647785;line-height:1.6;margin:0;max-width:19rem}.liga-stage__arrow{align-self:flex-end;color:#087fae;font-size:1.4rem;margin-top:auto}.liga-feature{align-items:center;background:#0e2639;display:grid;gap:5rem;grid-template-columns:1fr 1fr;padding:clamp(5rem,9vw,9rem) max(1.25rem,calc((100vw - 1280px)/2))}.liga-feature__canvas{background:#f3f8fa;border-radius:.7rem;box-shadow:0 25px 70px #0005;color:#0d2634;padding:clamp(1.2rem,3vw,2.3rem)}.liga-canvas__head{color:#62818e;display:flex;font-size:.65rem;font-weight:800;justify-content:space-between;letter-spacing:.06em}.liga-canvas__head span:last-child{color:#078a79}.liga-canvas__title{align-items:center;display:flex;font-size:clamp(1.4rem,2.5vw,2.3rem);font-weight:750;justify-content:space-between;letter-spacing:-.04em;padding:2.5rem 0}.liga-canvas__title span{color:#078cb8;font-size:2rem}.liga-canvas__row{align-items:center;border-top:1px solid #d4e1e6;display:grid;gap:1rem;grid-template-columns:auto 1fr auto;padding:1.25rem 0}.liga-canvas__row span{color:#078cb8;font-size:.75rem}.liga-canvas__row strong{font-size:.85rem}.liga-roles__list{border-top:1px solid #bccdd4;margin-top:5rem}.liga-roles__list article{align-items:center;border-bottom:1px solid #cbd9de;display:grid;gap:1.5rem;grid-template-columns:3rem 1fr 1fr auto;min-height:105px}.liga-roles__list h3{font-size:clamp(1.2rem,2vw,1.7rem);letter-spacing:-.03em;margin:0}.liga-roles__list article>span:last-child{color:#087fae;font-size:1.3rem}.liga-final{background:#0a5d85;padding:clamp(5rem,10vw,10rem) 1.25rem;text-align:center}.liga-final .liga-kicker{justify-content:center}.liga-final h2 em{color:#a5e8ff}.liga-final p:not(.liga-kicker){color:#d0ecf7;margin:1.5rem 0 2rem}.liga-footer{align-items:center;display:flex;gap:2rem;margin:auto;max-width:1440px;padding:2rem clamp(1.25rem,5vw,5rem)}.liga-footer :deep(img){width:120px}.liga-footer p,.liga-footer span,.liga-footer a{color:#9eafbc;font-size:.75rem}.liga-footer p{margin-right:auto}.liga-footer nav{display:flex;gap:1.4rem}.liga-footer a:hover{color:white}@media(max-width:900px){.liga-nav__links{display:none}.liga-hero__inner,.liga-feature{grid-template-columns:1fr}.liga-hero__inner{padding-top:5rem}.liga-workspace{max-width:630px;transform:none}.liga-hero__bottom{margin:0 1.25rem}.liga-feature{gap:3rem}.liga-section__heading{grid-template-columns:1fr}.liga-section__heading .liga-kicker{grid-column:auto}.liga-footer{flex-wrap:wrap}}@media(max-width:600px){.liga-nav{gap:.8rem;height:70px}.liga-nav__brand{width:105px}.liga-nav__actions{gap:.75rem}.liga-nav__login{font-size:.8rem}.liga-button--small{gap:.6rem}.liga-hero__inner{min-height:0;padding-bottom:3rem}.liga-hero h1{font-size:clamp(3.1rem,12vw,4.8rem)}.liga-hero__bottom span:last-child{display:none}.liga-workspace__side{padding:1rem .65rem}.liga-workspace__main{padding:1rem}.liga-workspace__body{min-height:0}.liga-workspace__cards{grid-template-columns:1fr}.liga-workspace__cards>div{grid-template-columns:auto 1fr;align-items:center}.liga-workspace__cards small{grid-column:2}.liga-stages{grid-template-columns:1fr;margin-top:3rem}.liga-stage,.liga-stage+.liga-stage{border-bottom:1px solid #cdd9de;border-right:0;min-height:0;padding:1.5rem 0}.liga-stage h3{margin:1.5rem 0 .6rem}.liga-stage__arrow{margin-top:.5rem}.liga-roles__list{margin-top:3rem}.liga-roles__list article{gap:.7rem;grid-template-columns:2rem 1fr auto;padding:1.3rem 0}.liga-roles__list p{grid-column:2/3}.liga-roles__list article>span:last-child{grid-column:3;grid-row:1}.liga-actions .liga-button{width:100%}.liga-footer{align-items:flex-start;flex-direction:column;gap:1.2rem}.liga-footer p{margin:0}}@media(prefers-reduced-motion:reduce){.liga-home *{animation:none!important;transition:none!important}}
</style>
