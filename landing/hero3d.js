/* ================================================================
   MatchPoint — Hero 3D (three.js)
   Pelotas de tenis flotando con luz lima, parallax al ratón.
   Solo se inicializa si hay WebGL, no hay prefers-reduced-motion
   y el hero está en pantalla. Degrada en silencio si falla.
   ================================================================ */
import * as THREE from "three";

(() => {
  const canvas = document.getElementById("hero-3d");
  if (!canvas) return;
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduced) { canvas.remove(); return; }

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: "low-power" });
  } catch (e) {
    canvas.remove();
    return;
  }

  const hero = canvas.parentElement;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(50, 1, 0.1, 60);
  camera.position.set(0, 0, 11);

  renderer.setClearColor(0x000000, 0);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));

  /* Luces: key fría suave + punto lima que da el glow de marca */
  scene.add(new THREE.AmbientLight(0x223322, 1.1));
  const key = new THREE.DirectionalLight(0xeef5e0, 1.6);
  key.position.set(-4, 6, 8);
  scene.add(key);
  const lime = new THREE.PointLight(0xc8f542, 42, 30, 1.8);
  lime.position.set(5, -2, 5);
  scene.add(lime);
  const rim = new THREE.PointLight(0x3f8f5f, 18, 26, 2);
  rim.position.set(-7, 3, -3);
  scene.add(rim);

  /* Pelotas: esfera mate lima + wireframe sutil encima (rollo tech-deportivo) */
  const isMobile = window.innerWidth < 700;
  const COUNT = isMobile ? 8 : 15;
  const balls = [];
  const felt = new THREE.MeshStandardMaterial({ color: 0xc8f542, roughness: 0.92, metalness: 0.04 });
  const dark = new THREE.MeshStandardMaterial({ color: 0x1d2b17, roughness: 0.95 });
  const wire = new THREE.MeshBasicMaterial({ color: 0xeaff9a, wireframe: true, transparent: true, opacity: 0.16 });

  for (let i = 0; i < COUNT; i++) {
    const r = 0.22 + Math.random() * 0.5;
    const geo = new THREE.SphereGeometry(r, 28, 28);
    const useDark = Math.random() < 0.25;
    const mesh = new THREE.Mesh(geo, useDark ? dark : felt);
    if (!useDark) {
      const w = new THREE.Mesh(geo, wire);
      w.scale.setScalar(1.004);
      mesh.add(w);
    }
    mesh.position.set(
      (Math.random() - 0.5) * 16,
      (Math.random() - 0.5) * 9,
      -2 - Math.random() * 7
    );
    mesh.userData = {
      baseY: mesh.position.y,
      speed: 0.25 + Math.random() * 0.5,
      phase: Math.random() * Math.PI * 2,
      amp: 0.35 + Math.random() * 0.6,
      rot: (Math.random() - 0.5) * 0.4,
    };
    scene.add(mesh);
    balls.push(mesh);
  }

  /* Parallax con ratón / dedo */
  let targetX = 0, targetY = 0, curX = 0, curY = 0;
  const onMove = (x, y) => {
    targetX = (x / window.innerWidth - 0.5) * 2;
    targetY = (y / window.innerHeight - 0.5) * 2;
  };
  window.addEventListener("mousemove", (e) => onMove(e.clientX, e.clientY), { passive: true });
  window.addEventListener("touchmove", (e) => {
    if (e.touches[0]) onMove(e.touches[0].clientX, e.touches[0].clientY);
  }, { passive: true });

  function resize() {
    const w = hero.clientWidth, h = hero.clientHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  resize();
  window.addEventListener("resize", resize);

  /* Solo renderiza cuando el hero es visible */
  let visible = true;
  new IntersectionObserver((entries) => { visible = entries[0].isIntersecting; }, { threshold: 0.02 }).observe(hero);

  const clock = new THREE.Clock();
  (function loop() {
    requestAnimationFrame(loop);
    if (!visible) return;
    const t = clock.getElapsedTime();
    for (const b of balls) {
      const u = b.userData;
      b.position.y = u.baseY + Math.sin(t * u.speed + u.phase) * u.amp;
      b.rotation.x += 0.002 + u.rot * 0.004;
      b.rotation.y += 0.003 - u.rot * 0.003;
    }
    curX += (targetX - curX) * 0.045;
    curY += (targetY - curY) * 0.045;
    camera.position.x = curX * 0.9;
    camera.position.y = -curY * 0.55;
    camera.lookAt(0, 0, -3);
    lime.position.x = 5 + Math.sin(t * 0.4) * 3;
    lime.position.y = -2 + Math.cos(t * 0.3) * 2;
    renderer.render(scene, camera);
  })();
})();
