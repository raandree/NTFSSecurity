using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.IO;
using Security2;

namespace NTFSSecurity
{
    public partial class ShowSimpleEffectiveAccessForm : Form
    {
        private IEnumerable<DirectoryInfo> directoryList;
        private IQueryable<SimpleFileSystemAccessRule> aceList;
        private IEnumerable<DirectoryTreeNode> searchResultByFolder;
        private int searchResultByFolderIndex;

        public IEnumerable<DirectoryInfo> DirectoryList
        {
            get { return directoryList; }
        }

        public IEnumerable<SimpleFileSystemAccessRule> AceList
        {
            get { return aceList; }
        }

        public ShowSimpleEffectiveAccessForm()
        {
            InitializeComponent();
        }

        public void BuildDirectoryTreeNodes()
        {
            string previousPath = string.Empty;
            DirectoryTreeNode previousNode;
            DirectoryTreeNode rootNode;

            var rootDirectory = directoryList.First();

            rootNode = new DirectoryTreeNode(rootDirectory.FullName, rootDirectory.Name, aceList.Where(ace => ace.FullName == rootDirectory.Name));
            previousNode = rootNode;
            trvDirectories.Nodes.Add(rootNode);

            foreach (var directory in directoryList.Skip(1))
            {
                if (previousNode.Name == directory.GetParent().FullName)
                {
                    var node = new DirectoryTreeNode(directory.FullName, directory.Name, aceList.Where(ace => ace.FullName == directory.FullName));
                    previousNode.Nodes.Add(node);
                }
                else
                {
                    previousNode = (DirectoryTreeNode)trvDirectories.Nodes.Find(directory.GetParent().FullName, true).FirstOrDefault();
                    if (previousNode != null)
                    {
                        var node = new DirectoryTreeNode(directory.FullName, directory.Name, aceList.Where(ace => ace.FullName == directory.FullName));
                        previousNode.Nodes.Add(node);
                    }
                    else
                    {
                        var node = new DirectoryTreeNode(directory.FullName, directory.Name, aceList.Where(ace => ace.FullName == directory.FullName));
                        previousNode.Nodes.Add(node);
                    }
                }
            }
        }

        public void BuildDirectoryTreeNodes(IEnumerable<DirectoryInfo> directoryList, IQueryable<SimpleFileSystemAccessRule> aceList)
        {
            this.directoryList = directoryList;
            this.aceList = aceList;

            this.BuildDirectoryTreeNodes();
        }

        private void trvDirectories_AfterSelect(object sender, TreeViewEventArgs e)
        {
            lstPermissions.Items.Clear();

            foreach (var ace in aceList.Where(ace => ace.FullName == e.Node.Name))
            {
                ListViewItem listItem = new ListViewItem();
                listItem.Name = e.Node.Name;
                listItem.Text = ace.Identity.AccountName;
                listItem.SubItems.AddRange(new string[] { ace.AccessRights.ToString(), ace.AccessControlType.ToString(), e.Node.FullPath });
                listItem.ImageIndex = 1;

                lstPermissions.Items.Add(listItem);
            }

            if (lstPermissions.Items.Count > 0)
            {
                foreach (ColumnHeader column in lstPermissions.Columns)
                {
                    column.AutoResize(ColumnHeaderAutoResizeStyle.ColumnContent);
                }
            }
        }

        private void chkRemoveFoldersWithoutAccess_CheckedChanged(object sender, EventArgs e)
        {
            if (chkRemoveFoldersWithoutAccess.Checked)
            {
                RemoveFoldersWithoutAccess((DirectoryTreeNode)trvDirectories.Nodes[0]);
            }
            else
            {
                trvDirectories.Nodes.Clear();
                BuildDirectoryTreeNodes();
            }
        }

        public void RemoveFoldersWithoutAccess(DirectoryTreeNode node)
        {
            for (int i = 0; i < node.Nodes.Count; i++)
            {
                if (node.Nodes[i].GetNodeCount(false) > 0)
                    RemoveFoldersWithoutAccess((DirectoryTreeNode)node.Nodes[i]);

                if (node.Nodes[i].Nodes.Count == 0 & ((DirectoryTreeNode)node.Nodes[i]).Acl.Count() == 0)
                {
                    node.Nodes.Remove(node.Nodes[i]);
                    i--;
                }
            }
        }

        private void btnSearchForFolder_Click(object sender, EventArgs e)
        {
            searchResultByFolder = null;
            searchResultByFolderIndex = 0;
            trvDirectories.HideSelection = false;

            searchResultByFolder = FindNodeByFolder((DirectoryTreeNode)trvDirectories.Nodes[0], txtSearchForFolder.Text);
            if (searchResultByFolder.Count() > 0)
            {
                btnSearchForFolderNext.Enabled = true;
                btnSearchForFolderPrev.Enabled = true;

                trvDirectories.SelectedNode = searchResultByFolder.First();
                searchResultByFolderIndex = 0;
            }
            else
            {
                btnSearchForFolderNext.Enabled = false;
                btnSearchForFolderPrev.Enabled = false;
            }
        }

        private IEnumerable<DirectoryTreeNode> FindNodeByFolder(DirectoryTreeNode node, string search)
        {
            if (node.Text.ToLower().Contains(search.ToLower()))
            {
                yield return node;
            }

            foreach (DirectoryTreeNode childNode in node.Nodes)
            {
                foreach (DirectoryTreeNode match in this.FindNodeByFolder(childNode, search))
                {
                    yield return match;
                }
            }
        }

        private IEnumerable<DirectoryTreeNode> FindNodeByIdentity(DirectoryTreeNode node, string search)
        {
            if (node.Acl.Where(ace => ace.Identity.AccountName.ToLower().Contains(search.ToLower())).Count() > 0)
            {
                yield return node;
            }

            foreach (DirectoryTreeNode childNode in node.Nodes)
            {
                foreach (DirectoryTreeNode match in this.FindNodeByIdentity(childNode, search))
                {
                    yield return match;
                }
            }
        }

        private void btnSearchForFolderNext_Click(object sender, EventArgs e)
        {
            if (searchResultByFolder.Count() > searchResultByFolderIndex + 1)
            {
                searchResultByFolderIndex++;
                trvDirectories.SelectedNode = searchResultByFolder.ElementAt(searchResultByFolderIndex);
            }
        }

        private void btnSearchForFolderPrev_Click(object sender, EventArgs e)
        {
            if (searchResultByFolderIndex - 1 > -1)
            {
                searchResultByFolderIndex--;
                trvDirectories.SelectedNode = searchResultByFolder.ElementAt(searchResultByFolderIndex);
            }
        }

        private void btnSearchForIdentityPrev_Click(object sender, EventArgs e)
        {
            if (searchResultByFolder.Count() > searchResultByFolderIndex + 1)
            {
                searchResultByFolderIndex++;
                trvDirectories.SelectedNode = searchResultByFolder.ElementAt(searchResultByFolderIndex);
            }
        }

        private void btnSearchForIdentityNext_Click(object sender, EventArgs e)
        {
            if (searchResultByFolderIndex - 1 > -1)
            {
                searchResultByFolderIndex--;
                trvDirectories.SelectedNode = searchResultByFolder.ElementAt(searchResultByFolderIndex);
            }
        }
    }
}