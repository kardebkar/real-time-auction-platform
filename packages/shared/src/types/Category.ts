export interface Category {
  id: string;
  name: string;
  description?: string;
  parentId?: string;
  children: Category[];
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateCategoryInput {
  name: string;
  description?: string;
  parentId?: string;
}