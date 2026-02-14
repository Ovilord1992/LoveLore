import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  await prisma.novel.upsert({
    where: { id: 'demo_novel' },
    update: {},
    create: {
      id: 'demo_novel',
      title: 'Тени Петербурга',
      description: 'Мистическая история в ночном Петербурге. Встреча с загадочным незнакомцем изменит всё...',
      author: 'Amoria Team',
      tags: ['мистика', 'романтика', 'Петербург'],
      version: 1,
      chaptersCount: 1,
      isPublished: true,
    },
  });

  console.log('Seed complete.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
